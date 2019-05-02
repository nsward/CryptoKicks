# CryptoKicks  
  
Address on Rinkeby testnet: <a href="https://rinkeby.etherscan.io/address/0xe1c41c9b88a61fc86f4c83c766eda60f3c8012da">0xe1c41c9b88a61Fc86f4C83c766eDa60f3C8012DA</a>  
  
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
