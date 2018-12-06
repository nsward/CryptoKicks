# Crypto Kicks  
  
ERC-721 contract for Apprent.io's Crypto Kicks. Still very much a work in progress. Some of the changes / additions to the standard ERC-721:  
  
- Instead of standard tokenURIs to store the metadata, we had talked about using IPFS, so the contract stores IPFS hashes as strings and returns the base ipfs url concatenated with the IPFS hash from the tokenURI() function.  My understanding is that we want these IPFS hashes to return a JSON blob that fits the "<a href="https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md">ERC721 Metadata JSON Schema</a>". This would be things like the shoe's name, the creator, any attributes, and another IPFS hash that returns the image of the shoe.
  
- The owner of the contract (original deployer) can add the kids' addresses to the contract to approve them to mint tokens up to the tokensPerStudent limit (i.e. 4 crpyto kicks per student). If the kids don't actually want to mint their own tokens on the blockchain, we can also just have the contract owner deploy all the metadata to IPFS and mint all the tokens, then send them to the kids' addresses.  
  
## To deploy on a local testchain
Make sure truffle is installed globally.  
```npm install -g truffle```  
  
```git clone https://github.com/nward13/CryptoKicks.git```  
```npm install```  
```truffle develop```  
```migrate --compile-all --reset```  
  
Contracts will be deployed to the default truffle develop instance on port 9545.
