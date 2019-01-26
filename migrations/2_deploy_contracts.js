const CryptoKicks = artifacts.require("./CryptoKicks.sol");

module.exports = function(deployer) {

    // Address of OpenSea Proxy Registry on Rinkeby:
    let proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";

    let name = "Crypto Kicks";
    let symbol = "CRK";

    deployer.deploy(
        CryptoKicks,
        name,
        symbol,
        proxyRegistryAddress,
        {gas: 5000000}
    );
}