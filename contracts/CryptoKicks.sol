pragma solidity 0.5.2;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";
import "./ProxyRegistry.sol";
import "./Strings.sol";


/**
 * @title CryptoKicks
 * @author Nick Ward
 * @dev ERC721 contract for Apprent.io Crypto-Kicks
 */
contract CryptoKicks is ERC721Full, Ownable, MinterRole {
    // Note: no ownable functions. Only included to allow owner to edit
    // OpenSea storefront

    // ===============
    // State Variables and Data Structures:
    // ===============

    // Address of OpenSea Proxy Registry:
    // '0xf57b2c51ded3a29e6891aba85459d600256cf317' on Rinkeby
    address public proxyRegistryAddress;

    // Tracks the total number of tokens minted. Differs from totalSupply
    // in that the length of the _allTokens array decreases when tokens
    // are burned, which would cause tokenId collisions as we are using
    // incremental ids
    uint public totalMinted;

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
     */
    constructor(
        string memory _name, 
        string memory _symbol, 
        address _proxyRegistryAddress
    ) 
        ERC721Full(_name, _symbol) 
        public 
    {
        require(_proxyRegistryAddress != address(0), "Proxy Registry required.");
        proxyRegistryAddress = _proxyRegistryAddress;
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
        onlyMinter
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
        // tokens can only be burned by owner or approved
        require(_isApprovedOrOwner(msg.sender, tokenId));

        // Burn the token
        _burn(tokenId);

        return true;
    }


    // ===============
    // Internal State-Transition Functions:
    // ===============

    /**
     * @dev Internal function to mint a new token
     * Reverts if the given token ID already exists
     * @param to address the beneficiary that will own the minted token
     * @param tokenId uint256 ID of the token to be minted by the msg.sender
     * @param ipfsHash ipfs hash of token metadata
     */
    function _mint(address to, uint256 tokenId, string memory ipfsHash) internal {
        super._mint(to, tokenId);

        // Increment the totalMinted value
        totalMinted = totalMinted.add(1);

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
        return Strings.strConcat(tokenBaseURI, tokenIPFSHashes[tokenId]);
    }
    
}