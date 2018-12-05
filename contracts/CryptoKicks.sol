pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
// import "./OwnableDelegateProxy.sol";
import "./ProxyRegistry.sol";
import "./StudentRole.sol";
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

    // Used to store IPFS hashes, which use multihash format
    // (first byte is the hash function used, next byte is the size of
    // the hash, remainder is the hash itself)
    // https://github.com/saurfang/ipfs-multihash-on-solidity
    struct Multihash {
        bytes32 digest;
        uint8 hashFunction;
        uint8 size;
    }

    // Keeps track of the number of tokens each student has minted
    // address => number of tokens minted
    mapping (address => uint) public mintedTokensCount;  

    // Keeps track of the minter of each token, so that students can burn
    // their tokens if they still own them, allowing them to mint another
    // token if they have already reached tokensPerStudent limit
    // tokenId => student who minted it
    mapping (uint => address) public minter; 

    // Used instead of the inerited _tokenURIs mapping. Stores the IPFS
    // hash of the token metadata in multihash format. Still returned in 
    // string format by tokenURI() function to maintain compatibility 
    // with ERC721 standard
    // tokenId => multihash
    mapping (uint => Multihash) public tokenIPFSHashes;  

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
        string _name, 
        string _symbol, 
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

    // Note: onlyStudent() modifier is inherited from StudentRoles contract

    /**
     * @dev Students can only mint if they have minted fewer than the
     * tokensPerStudent limit
     */
    modifier onlyUnderMintLimit() {
        require(isUnderMintLimit(msg.sender), "Already minted max number of tokens");
        _;
    }


    // ===============
    // External / Public State-Transition Functions:
    // ===============

    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param _digest the IPFS hash that returns a JSON blob with the token
     * metadata. Expected in multihash format with digest representing the
     * hash itself. **Note that multihash paramaters are expected in hexadecimal
     * form
     * (https://github.com/multiformats/multihash)
     * @param _hashFunction The hash function used (following multihash format)
     * @param _size Length of the hash in bytes
     * @return The tokenId of the minted token
     */
    function mintTo(address to, bytes32 _digest, uint8 _hashFunction, uint8 _size)
        external
        onlyStudent
        onlyUnderMintLimit
        returns (uint)
    {
        // Grab the next tokenId. tokenId's need to start at 0 and increment
        // by 1 in order for OpenSea storefront to be able to backfill tokens
        uint newTokenId = _getNextTokenId();

        // Mint the new token
        _mint(to, newTokenId);

        // Set the token URI data / IPFS hash of the metadata
        _setTokenIPFSHash(newTokenId, _digest, _hashFunction, _size);

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

        // TODO: make sure this works with inherited library
        // Subtract 1 from the student's minted tokens count
        address student = minter[tokenId];
        mintedTokensCount[student] = mintedTokensCount[student].sub(1);

        // delete the tokenId from the minter mapping
        delete minter[tokenId];

        // delete the token's metadata IPFS hash
        delete tokenIPFSHashes[tokenId];
    }

    /**
     * @dev Internal function to mint a new token
     * Reverts if the given token ID already exists
     * @param to address the beneficiary that will own the minted token
     * @param tokenId uint256 ID of the token to be minted by the msg.sender
     */
    function _mint(address to, uint256 tokenId) internal {
        super._mint(to, tokenId);

        // TODO: Make sure this works with inherited library
        // Increment the minter's minted tokens count
        mintedTokensCount[msg.sender] = mintedTokensCount[msg.sender].add(1);

        // Add the token minter to the minter mapping
        minter[tokenId] = msg.sender;

    }

    /**
     * @dev Internal function to set the token IPFS Hash for a given token's
     * metadata. Reverts if the token ID does not exist
     * @param _digest the IPFS hash that returns a JSON blob with the token
     * metadata. Expected in multihash format with digest representing the
     * hash itself. **Note that multihash paramaters are expected in hexadecimal
     * form
     * (https://github.com/multiformats/multihash)
     * @param _hashFunction The hash function used (following multihash format)
     * @param _size Length of the hash in bytes
     */
    function _setTokenIPFSHash(
        uint256 tokenId, 
        bytes32 _digest, 
        uint8 _hashFunction, 
        uint8 _size
    ) 
        internal 
    {
        require(_exists(tokenId));

        // TODO: make sure this works
        Multihash memory IPFSHash = Multihash(_digest, _hashFunction, _size);
        tokenIPFSHashes[tokenId] = IPFSHash;
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
        return mintedTokensCount[_student] <= tokensPerStudent;
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
        return totalSupply().add(1);
    }

    /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
   */
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
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }


    // TODO: returning string conforms to the ERC721 standard, but implies
    // that we are returning the UTF-8 encoded IPFS hash, when we are actually
    // returning the hex form
    /**
     * @dev Returns an URI for a given token ID. Throws if the token ID 
     * does not exist. May return an empty string.
     * We are returning the IPFS hash in string form (the concatenation of
     * the 3 multihash paramaters), but the tokenURI() function is used
     * to maintain consistency with the ERC721 standard
     * @param tokenId uint256 ID of the token to query
     * @return IPFS hash of the token's metadata (in hexadecimal)
     */
    function tokenURI(uint256 tokenId) external view returns (string) {

        // Hash = hashFunction (2 bytes) + size (2 bytes) + digest
        require(_exists(tokenId));
        Multihash memory tokenIPFSHash = tokenIPFSHashes[tokenId];
        string memory _hashFunction = Strings.uint2str(uint(tokenIPFSHash.hashFunction));
        string memory _size = Strings.uint2str(uint(tokenIPFSHash.size));
        string memory _digest = Strings.uint2str(uint(tokenIPFSHash.digest));
        string memory _fullHash = Strings.strConcat(_hashFunction, _size, _digest);
        return _fullHash;
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