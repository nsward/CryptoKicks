const CryptoKicksContract = artifacts.require('../contracts/CryptoKicks');
const assert = require('assert');
const { expectThrow } = require('./helpers/expectThrow');

const EVMRevert = 'revert';


contract("CryptoKicks", function(accounts) {
    let Kicks;
    let proxyRegistryAddress;
    let name;
    let symbol;
    let tokensPerStudent;
    let newTokensPerStudent;
    const owner = accounts[0];
    const student = accounts[1];
    const buyer = accounts[2];
    const anyone = accounts[3];

    // The URI to which our IPFS hash should be appended. This might
    // change depending on how we connect to IPFS (i.e. Infura vs.
    // our own node)
    const ipfsURIBase = 'https://gateway.ipfs.io/ipfs/';

    // Example of what `ipfs add` will return (a base58 encoded string)
    const ipfsHash = 'QmbyizSHLirDfZhms75tdrrdiVkaxKvbcLpXzjB5k34a31';
    

    beforeEach("Instantiate CryptoKicks Contract", async() => {
        // Address of OpenSea Proxy Registry on Rinkeby:
        proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";
        name = "Crypto Kicks";
        symbol = "CRK";
        tokensPerStudent = 4;
        newTokensPerStudent = tokensPerStudent + 1

        Kicks = await CryptoKicksContract.new(
            name,
            symbol,
            proxyRegistryAddress,
            tokensPerStudent,
            {from: owner, gas: 5000000});
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

        // Check that tokensPerStudent initialized correctly
        const tokensPerStudentReturned = await Kicks.tokensPerStudent();
        assert.equal(tokensPerStudentReturned, tokensPerStudent, "Contract returned incorrect tokensPerStudent value");

    });


    it("Check owner functions", async() => {

        // Check that student can't mint before being added
        await expectThrow(
            Kicks.mintTo(student, ipfsHash, {from:student}), 
            EVMRevert
        );

        // Check that only owner can add students
        await expectThrow(
            Kicks.addStudent(student, {from:anyone}),
            EVMRevert
        );

        // Check that owner can successfully add student
        await Kicks.addStudent(student, {from:owner});

        // Check that student can mint tokens now
        // Mint a token
        await Kicks.mintTo(
            student, 
            ipfsHash,
            {from:student}
        );

        // Check that owner can successfully remove students
        await Kicks.removeStudent(student, {from:owner});

        // Check that students can't mint tokens now
        await expectThrow(
            Kicks.mintTo(student, ipfsHash, {from:student}),
            EVMRevert
        );

        // Check that only owner can set tokens per student
        await expectThrow(
            Kicks.setTokensPerStudent(newTokensPerStudent, {from:anyone}), 
            EVMRevert
        );

        // Check that owner can successfully set tokensPerStudent
        await Kicks.setTokensPerStudent(newTokensPerStudent, {from:owner});
        assert.equal(
            await Kicks.tokensPerStudent(), 
            newTokensPerStudent, 
            "Owner can't change tokensPerStudent."
        );
        
    });


    it("Check Pasuable functionality", async() => {

        // Approve student to mint
        await Kicks.addStudent(student, {from:owner});

        // Mint a token
        await Kicks.mintTo(
            student, 
            ipfsHash,
            {from:student}
        );

        // get token id
        const userTokenId = (await Kicks.tokenOfOwnerByIndex(student, 0)).toString();

        // Pause the contract
        await Kicks.pause({from:owner});

        // Check that minting fails when paused
        await expectThrow(
            Kicks.mintTo(student, ipfsHash, {from:student}),
            EVMRevert
        );

        // Check that approve() fails when paused
        await expectThrow(
            Kicks.approve(anyone, userTokenId, {from:student}),
            EVMRevert
        );

        // Check that setApprovalForAll() fails when paused
        await expectThrow(
            Kicks.setApprovalForAll(anyone, true, {from:student}),
            EVMRevert
        );

        // Check that transferFrom() fails when paused
        await expectThrow(
            Kicks.transferFrom(student, anyone, userTokenId, {from:student}),
            EVMRevert
        );

        // Unpause the contract
        await Kicks.unpause({from:owner});

        // Check that minting works again when unpaused
        await Kicks.mintTo(
            student, 
            ipfsHash,
            {from:student}
        );

        // Check that approve() works again once unpaused
        await Kicks.approve(anyone, userTokenId, {from:student})

        // Check that setApprovalForAll() works once unpaused
        await Kicks.setApprovalForAll(anyone, true, {from:student})

        // Check that transferFrom() works once unpaused
        await Kicks.transferFrom(student, anyone, userTokenId, {from:student})

    });


    it("Check state updates after minting a token", async() => {

        // Approve student to mint
        await Kicks.addStudent(student, {from:owner});

        // Mint a token
        await Kicks.mintTo(
            student, 
            ipfsHash,
            {from:student}
        );

        // Check that total supply is updated
        const totalSupply1 = await Kicks.totalSupply();
        assert.equal(totalSupply1, 1, "Total supply not updated on mint.");

        // Check that user's balance is updated
        const userBalance1 = await Kicks.balanceOf(student);
        assert.equal(userBalance1, 1, "Minter balance not updated.");

        // Check that user's mintedTokensCount is updated
        const userMintCount = await Kicks.mintedTokensCount(student);
        assert.equal(userMintCount, 1, "Minter mintedTokensCount not updated");

        // get token id
        const usertokenId = (await Kicks.tokenOfOwnerByIndex(student, 0)).toString();

        // Check that minter array is properly updated
        assert.equal(
            await Kicks.minter(usertokenId),
            student,
            "Minter array not updated properly."
        );
    });
    
    
    it("Check that students can mint correct number of tokens", async() => {
        // Approve student to mint
        await Kicks.addStudent(student, {from:owner});

        // Mint max number of tokens
        for (let i = 0; i < tokensPerStudent; i++) {
            await Kicks.mintTo(
                student, 
                ipfsHash,
                {from:student}
            );
        };

        // Check that user's balance is updated
        const userBalance1 = await Kicks.balanceOf(student);
        assert.equal(userBalance1, tokensPerStudent, "Minter balance not updated after multiple tokens minted.");

        // Check that student can't mint more than limit
        await expectThrow(
            Kicks.mintTo(student, ipfsHash, {from:student}),
            EVMRevert
        );

        // Check that student can burn token
        const firstTokenId = (await Kicks.tokenOfOwnerByIndex(student, 0)).toString();
        await Kicks.burn(firstTokenId, {from:student});
        const newFirstTokenId = (await Kicks.tokenOfOwnerByIndex(student, 0)).toString();
        assert.equal(newFirstTokenId > firstTokenId, true, "Token not burned properly");

        // Check that student can mint again after burning token
        await Kicks.mintTo(
            student, 
            ipfsHash,
            {from:student}
        );
        
        // Check that student can mint again once tokensPerStudent is raised
        await Kicks.setTokensPerStudent(newTokensPerStudent, {from:owner});
        for (let i = tokensPerStudent; i < newTokensPerStudent; i++) {
            await Kicks.mintTo(
                student, 
                ipfsHash,
                {from:student}
            );
        }
        
        // Check that student can't mint more than new limit
        await expectThrow(
            Kicks.mintTo(student, ipfsHash, {from:student}),
            EVMRevert
        );

        // Check that tokensPerStudent can be set below the number of
        // tokens a student has already minted without issue
        await Kicks.setTokensPerStudent(1, {from:owner});
        
    });


    it("Check URI return", async() => {     

        // Approve student to mint
        await Kicks.addStudent(student, {from:owner});

        // Check that minting a token with invalid length string fails
        await expectThrow(
            Kicks.mintTo(student, ipfsHash + 'q', {from:student}), 
            EVMRevert
        );

        // Mint a token
        await Kicks.mintTo(
            student, 
            ipfsHash,
            {from:student}
        )

        // get token id
        const usertokenId = (await Kicks.tokenOfOwnerByIndex(student, 0)).toString();

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