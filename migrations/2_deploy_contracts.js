// // Token name
    // string private constant _name = "Crypto Kicks";

    // // Token symbol
    // string private constant _symbol = "CRK";

const CryptoKicks = artifacts.require("./CryptoKicks.sol");

module.exports = function(deployer) {

    // Address of OpenSea Proxy Registry on Rinkeby:
    let proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";

    let name = "Crypto Kicks";
    let symbol = "CRK";
    let tokensPerStudent = 4;


    deployer.deploy(
        CryptoKicks,
        name,
        symbol,
        proxyRegistryAddress,
        tokensPerStudent,
        {gas: 5000000}
    );
}