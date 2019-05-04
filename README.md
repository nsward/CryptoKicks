# CryptoKicks  
  
Address on Rinkeby testnet: <a href="https://rinkeby.etherscan.io/address/0xa6300e6d9ace0d9622639cbebada3dd5bfeab34d#code">0xa6300e6d9ace0d9622639cbebada3dd5bfeab34d</a>  
  
ERC-721 contract for Apprent.io's CryptoKicks.  
  
## To deploy on a local testchain
Make sure truffle is installed globally.  
```npm install -g truffle```  
  
```git clone https://github.com/nsward/CryptoKicks.git```  
```cd CryptoKicks```  
```npm install```  
```truffle develop```  
```migrate --compile-all --reset```  
  
Contracts will be deployed to the default truffle develop instance on port 9545.  
  
## To run tests  
Make sure truffle is installed globally.  
```npm install -g truffle```  
  
```git clone https://github.com/nsward/CryptoKicks.git```   
```cd CryptoKicks```  
```npm install```  
```truffle test```  
