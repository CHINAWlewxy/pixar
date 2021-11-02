const { utils } = require('ethers');
const { Contract, getDefaultProvider, Wallet,BigNumber } = require('ethers');
const provider = getDefaultProvider('https://data-seed-prebsc-2-s2.binance.org:8545');
const wallet = new Wallet('0xff059c1e1c2fac3d0cd2ac803d77b85a94584eab7384aa1a6e7728b5019dbb7f', provider);
const GasLimit = 10500000;             

//token
const contractPlatformTokenAddr = "0x7b3755F969BeFd89d7057128052bbd085858C808";
let jsonToken = require('../../build/contracts/WrappedToken.json');
const abiToken = jsonToken.abi;
const contractPlatformTokenHandler = new Contract(contractPlatformTokenAddr, abiToken, wallet);

//flip
const flipAddr = "0x50C95dF1cFFECD446368F85b3E764Ee564F04fa8";
let flipJsonToken = require('../../build/contracts/flip.json');
const flipAbiToken = flipJsonToken.abi;
const flipHandler = new Contract(flipAddr, flipAbiToken, wallet);
const Unit = 1000000000000000000n;

async function Test_betAndFlip(){
    try {
        console.log("-----betAndFlip start----");
        let approveRes =  await contractPlatformTokenHandler.approve(flipAddr,1000n * Unit,{gasLimit:GasLimit});
        // console.log("========approveRes========",approveRes);
        let res =  await flipHandler.betAndFlip(10n * Unit,0,{gasLimit:GasLimit});
        console.log("-----betAndFlip end----");
        console.log("========res========",res);

        setTimeout(async() => {
            let getResultOfLastFlip = await flipHandler.getResultOfLastFlip();
            console.log("========getResultOfLastFlip=======", getResultOfLastFlip)
        }, 1000);
        
        // let ret = await flipHandler.getAddrAllTokenIds("0xEdd7180D9356895E833c4781cF2733af76CC3A50",10,1)
        // console.log("========res========",ret);
    } catch (e){
        console.log("err -->",e);
    }
}
// async function TestDraw(){
//     try {
//         console.log("-----draw -----");
//         const constantsOne = BigInt(10000000000000000000);
//         let approveRes = await contractPlatformTokenHandler.approve(BlindBox_contractAddr,constantsOne,{gasLimit:GasLimit});
//         console.log("approve===>",approveRes);

//         let drawRes = await BlindBox_contractHandler.Draw(1,10,"0x4936e6A6A989b4B6101D7Bd70a8e494649853360",{gasLimit:GasLimit});
//         console.log("draw ===> ",drawRes);

//     }catch (e){
//         console.log("err -->",e);
//     }

// }

async function TestInit(){
    try {    
        let getLinkRand = await flipHandler.getLinkRand();
        console.log("========getLinkRand========",getLinkRand);
        let getRandomNumber = await flipHandler.init("0xEdd7180D9356895E833c4781cF2733af76CC3A50",{gasLimit:GasLimit});
        console.log("========res========",getRandomNumber);
    } catch (e){
        console.log("err -->",e);
    }
}

async function main(){
    //await TestMintKey();
    // await Test_betAndFlip();
    await TestInit();
}

main().catch(err =>{
    console.log("err",err);
});