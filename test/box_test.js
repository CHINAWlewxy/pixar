const { utils } = require('ethers');

const BlindBox = artifacts.require("BlindBox");

const WrappedToken = artifacts.require("WrappedToken");
const WrappedPlatformToken = artifacts.require('WrappedPlatformToken');
contract ('Mint',async accounts =>{

    it("deployed",async() =>{
        let blindBox = await BlindBox.deployed();
        const config = await staking.QueryConfig();
        console.log(config);

    });


});
