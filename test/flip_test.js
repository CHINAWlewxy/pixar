const { utils } = require('ethers');

const flip = artifacts.require("flip");
// const contractPlatformTokenAddr = "0x946dCE22b55808B87072ef2Fb8Dfb7645835a5A4";
const contractPlatformTokenAddr = "0x946dCE22b55808B87072ef2Fb8Dfb7645835a5A4";
let jsonToken = require('../build/contracts/WrappedToken.json');
const abiToken = jsonToken.abi;
const contractPlatformTokenHandler = new Contract(contractPlatformTokenAddr, abiToken, wallet);


const kToken = "0x5e015c65a2de4f219c4e2cb78c7d0b9af1940e2f"

contract ('Mint',async accounts =>{

    it("deployed",async() =>{
        let blindBox = await BlindBox.deployed();
        const config = await staking.QueryConfig();
        console.log(config);

    });


});
