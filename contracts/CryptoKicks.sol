pragma solidity 0.5.2;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "./StudentRole.sol";
import "./ProxyRegistry.sol";
import "./Strings.sol";


/**
 * @title CryptoKicks
 * @dev ERC721 contract for Apprent.io Crypto-Kicks
 */
contract CryptoKicks is Pausable, StudentRole, ERC721Full {
    // Note: Ownable functionality is inherited from StudentRole contract

    // ===============
    // State Variables and Data Structures:
    // ===============

    // Address of OpenSea Proxy Registry on Rinkeby:
    // '0xf57b2c51ded3a29e6891aba85459d600256cf317'
    address public proxyRegistryAddress;

    // Max number of tokens that each student can mint. Can be set by 
    // contract owner
    uint public tokensPerStudent;

    // Tracks the total number of tokens minted. Differs from totalSupply
    // in that the length of the _allTokens array decreases when tokens
    // are burned, which can cause tokenId collisions as we are using
    // incremental ids
    uint public totalMinted;

    // Keeps track of the number of tokens each student has minted
    // address => number of tokens minted
    mapping (address => uint) public mintedTokensCount;  

    // Keeps track of the minter of each token, so that students can burn
    // their tokens if they still own them, allowing them to mint another
    // token if they have already reached tokensPerStudent limit
    // tokenId => student who minted it
    mapping (uint => address) public minter; 

    // Used instead of the inerited _tokenURIs mapping, becuase openZeppelin
    // altered visibility of the tokenURI mapping in their ERC721 
    // implementation, requiring a separate mapping in order to return
    // the correct URI from tokenURI (tokenBaseURI + tokenIPFSHash). 
    // Stores the IPFS hash of the token metadata as a string.
    // tokenId => hash
    mapping (uint => string) public tokenIPFSHashes;  

    // Base URI. TokenURI's are formed by concatenating baseURI and
    // the token's IPFS hash
    // string public tokenBaseURI = "https://ipfs.infura.io/ipfs/";
    string public tokenBaseURI = "https://gateway.ipfs.io/ipfs/";

    // ===============
    // Constructor:
    // ===============

    /**
     * @dev Constructor
     * @param _name The name of the tokens
     * @param _symbol The token ticker symbol
     * @param _proxyRegistryAddress address of the OpenSea ProxyRegistry contract
     * @param _tokensPerStudent Max number of tokens each student can mint
     */
    constructor(
        string memory _name, 
        string memory _symbol, 
        address _proxyRegistryAddress, 
        uint _tokensPerStudent) 
        ERC721Full(_name, _symbol) 
        public 
    {
        require(_proxyRegistryAddress != address(0), "Proxy Registry required.");
        require(_tokensPerStudent > 0, "tokensPerStudent can not be 0.");
        proxyRegistryAddress = _proxyRegistryAddress;
        tokensPerStudent = _tokensPerStudent;
    }


    // ===============
    // Modifiers:
    // ===============

    /**
     * @dev Students can only mint if they have minted fewer than the
     * tokensPerStudent limit
     */
    modifier onlyUnderMintLimit() {
        require(isUnderMintLimit(msg.sender), "Already minted max number of tokens");
        _;
    }


    // ===============
    // External State-Transition Functions:
    // ===============

    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param ipfsHash the IPFS hash that returns a JSON blob with the token
     * metadata. Expected as base58 encoded string in multihash format 
     * (first byte is hash functino used, second byte is size of digest,
     * remainder is digest)
     * (https://github.com/multiformats/multihash)
     * @return The tokenId of the minted token
     */
    function mintTo(address to, string calldata ipfsHash)
        external
        onlyStudent
        onlyUnderMintLimit
        whenNotPaused
        returns (uint)
    {
        require(to != address(0), "Can not mint token to 0x address");

        // Note: This prevents the addition of arbitrary length data and
        // works with the most common ipfs hash implementations, but if more
        // than students are minting tokens, this should be "future-proofed"
        // using multihash storage format to match any ipfs hash implementation
        require(bytes(ipfsHash).length <= 46, "Max length for IPFS Hash string is 46 bytes");

        // Grab the next tokenId. tokenId's need to start at 0 and increment
        // by 1 in order for OpenSea storefront to be able to backfill tokens
        uint newTokenId = _getNextTokenId();

        // Mint the new token
        _mint(to, newTokenId, ipfsHash);

        return newTokenId;
    }

    /**
     * @dev Function to burn tokens. msg.sender must be both the original
     * minter and either the current owner or an agent approved by the
     * current owner. Allows students to burn old tokens (assuming they
     * still own them) so they can mint new crypto kicks
     * @param tokenId The ID of the token to burn
     * @return A boolean that indicates if the operation was successful.
     */
    function burn(uint256 tokenId) external returns (bool) {
        
        // Check that the function caller is both the original minter of
        // the token and either the either the current owner or an agent 
        // approved by the current owner
        require(
            _isOriginalMinter(msg.sender, tokenId) &&
            _isApprovedOrOwner(msg.sender, tokenId)
        );

        // Burn the token
        _burn(ownerOf(tokenId), tokenId);

        return true;
    }


    // ===============
    // Internal State-Transition Functions:
    // ===============

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * @param owner owner of the token to burn
     * @param tokenId uint256 ID of the token being burned by the msg.sender
     */
    function _burn(address owner, uint256 tokenId) internal {

        super._burn(owner, tokenId);

        // Subtract 1 from the student's minted tokens count
        address student = minter[tokenId];
        mintedTokensCount[student] = mintedTokensCount[student].sub(1);

        // delete the tokenId from the minter mapping
        delete minter[tokenId];
    }

    /**
     * @dev Internal function to mint a new token
     * Reverts if the given token ID already exists
     * @param to address the beneficiary that will own the minted token
     * @param tokenId uint256 ID of the token to be minted by the msg.sender
     */
    function _mint(address to, uint256 tokenId, string memory ipfsHash) internal {
        super._mint(to, tokenId);

        // Increment the totalMinted value
        totalMinted = totalMinted.add(1);

        // Increment the minter's minted tokens count
        mintedTokensCount[msg.sender] = mintedTokensCount[msg.sender].add(1);

        // Add the token minter to the minter mapping
        minter[tokenId] = msg.sender;

        // Set the token URI data / IPFS hash of the metadata
        _setTokenIPFSHash(tokenId, ipfsHash);
    }

    /**
     * @dev Internal function to set the token IPFS Hash for a given token's
     * metadata. Reverts if the token ID does not exist
     * @param ipfsHash the IPFS hash that returns a JSON blob with the token
     * metadata. 
     */
    function _setTokenIPFSHash(
        uint tokenId,
        string memory ipfsHash
    ) 
        internal 
    {
        require(_exists(tokenId));
        tokenIPFSHashes[tokenId] = ipfsHash;
    }


    // ===============
    // View Functions:
    // ===============

    /**
     * @dev Internal Function to check whether the student has reached
     * their max number of minted tokens
     * @param _student Address of the student
     * @return A boolean indicating whether the student is under the token
     * minting limit
     */
    function isUnderMintLimit(address _student) internal view returns (bool) {
        return mintedTokensCount[_student] < tokensPerStudent;
    }

    /**
     * @dev Internal Function to check whether the _sender is the same
     * address that originally minted the token
     * @param _sender Address to check against the token's minter
     * @return A boolean indicating whether the _sender is the original
     * minter of the token
     */
    function _isOriginalMinter(address _sender, uint tokenId) 
        internal 
        view 
        returns (bool) 
    {
        return (_sender == minter[tokenId]);
    }

    /**
     * @dev Internal Function to get the next tokenId. tokenId's need to 
     * start at 0 and increment by 1 in order for OpenSea storefront to 
     * be able to backfill tokens
     * @return The next tokenId
     */
    function _getNextTokenId() internal view returns (uint) {
        return totalMinted;
    }

   /**
     * @dev Override the isApprovedForAll() function to whitelist user's
     * OpenSea proxy accounts to enable gas-less listings.
     * @param owner owner address which you want to query the approval of
     * @param operator operator address which you want to query the approval of
     * @return bool whether the given operator is approved by the given owner
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
    * @dev Returns URI for a given token ID
    * Throws if the token ID does not exist. May return an empty string.
    * @param tokenId uint256 ID of the token to query
    */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId));
        // string memory foo = super.tokenURI(tokenId);
        // return Strings.strConcat(tokenBaseURI, _tokenURIs[tokenId]);
        return Strings.strConcat(tokenBaseURI, tokenIPFSHashes[tokenId]);
    }


    // ===============
    // Function modifier overrides:
    // ===============

    // These are all here just to make these functions Pausable so that
    // they can be stopped temporarily in the event of a security concern 

    function approve(address to, uint256 tokenId) 
        public 
        whenNotPaused 
    {
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address to, bool approved) 
        public
        whenNotPaused
    {
        super.setApprovalForAll(to, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        whenNotPaused
    {
        super.transferFrom(from, to, tokenId);
    }


    // ===============
    // Owner Functions:
    // ===============

    function setTokensPerStudent(uint _numTokens) public onlyOwner {
        // Note that _numTokens is not required to be > 0, so this could
        // be used to effectively pause minting

        tokensPerStudent = _numTokens;
    }
    
}