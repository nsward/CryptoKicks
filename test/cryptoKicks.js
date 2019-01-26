const CryptoKicksContract = artifacts.require('../contracts/CryptoKicks');
const assert = require('assert');
const { expectThrow } = require('./helpers/expectThrow');

const EVMRevert = 'revert';


contract("CryptoKicks", function(accounts) {
  let Kicks;
  let proxyRegistryAddress;
  let name;
  let symbol;
  const minter = accounts[0];
  const newMinter = accounts[1];
  const buyer = accounts[2];
  const anyone = accounts[3];

  // The URI to which our IPFS hash should be appended
  const ipfsURIBase = 'https://gateway.ipfs.io/ipfs/';

  // Example of what `ipfs add` will return (a base58 encoded string)
  const ipfsHash = 'QmbyizSHLirDfZhms75tdrrdiVkaxKvbcLpXzjB5k34a31';

  beforeEach("Instantiate CryptoKicks Contract", async() => {
    // Address of OpenSea Proxy Registry on Rinkeby:
    proxyRegistryAddress = web3.utils.toChecksumAddress(
      "0xf57b2c51ded3a29e6891aba85459d600256cf317"
    );
    name = "Crypto Kicks";
    symbol = "CRK";

    Kicks = await CryptoKicksContract.new(
      name,
      symbol,
      proxyRegistryAddress,
      {from: minter, gas: 5000000});
  });


  it("Check that constructor arguments were initialized correctly", async() => {
    // Check OpenSea proxy registry address
    const proxyRegistryAddressReturned = await Kicks.proxyRegistryAddress();
    assert.equal(
      proxyRegistryAddressReturned, 
      proxyRegistryAddress, 
      "Incorrect proxy registry address"
    );

    // Check contract name
    const nameReturned = await Kicks.name();
    assert.equal(nameReturned, name, "Incorrect token name.");

    // Check contract symbol
    const symbolReturned = await Kicks.symbol();
    assert.equal(symbolReturned, symbol, "Incorrect token symbol.");

  });


  it("Check minter functions", async() => {

    // Check that no one can mint before being added as minter
    await expectThrow(
      Kicks.mintTo(newMinter, ipfsHash, {from:newMinter}), 
      EVMRevert
    );

    // Check that only minter can add minters
    await expectThrow(
      Kicks.addMinter(newMinter, {from:anyone}),
      EVMRevert
    );

    // Check that minter can successfully add minter
    await Kicks.addMinter(newMinter, {from:minter});

    // Check that minter can mint tokens now
    // Mint a token
    await Kicks.mintTo(
      newMinter, 
      ipfsHash,
      {from:minter}
    );
      
  });

  it("Check state updates after minting a token", async() => {

    // Mint a token
    await Kicks.mintTo(
      minter, 
      ipfsHash,
      {from:minter}
    );

    // Check that total supply is updated
    const totalSupply1 = await Kicks.totalSupply();
    assert.equal(totalSupply1, 1, "Total supply not updated on mint.");

    // Check that user's balance is updated
    const userBalance1 = await Kicks.balanceOf(minter);
    assert.equal(userBalance1, 1, "Minter balance not updated.");

  });


  it("Check URI return", async() => {     

    // Check that minting a token with invalid length string fails
    await expectThrow(
      Kicks.mintTo(minter, ipfsHash + 'q', {from:minter}), 
      EVMRevert
    );

    // Mint a token
    await Kicks.mintTo(
      minter, 
      ipfsHash,
      {from:minter}
    )

    // get token id
    const usertokenId = (await Kicks.tokenOfOwnerByIndex(minter, 0)).toString();

    // Grab the uri returned from the contract (should be uriBase + ipfsHash)
    const uri = await Kicks.tokenURI(usertokenId);

    // Check that contract stores and returns token's URI correctly
    const baseReturned = uri.slice(0, ipfsURIBase.length);
    const hashReturned = uri.slice(ipfsURIBase.length);
    assert.equal(
      uri.length, 
      ipfsURIBase.length + ipfsHash.length, 
      "Contract returned uri of incorrect length."
    );
    assert.equal(
      baseReturned,
      ipfsURIBase,
      "Contract returned incorrect uri base."
    );
    assert.equal(
      hashReturned,
      ipfsHash,
      "Contract returned uri with incorrect ipfs hash."
    );

  });

});