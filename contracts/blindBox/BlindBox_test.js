const { utils } = require('ethers');
const { Contract, getDefaultProvider, Wallet,BigNumber } = require('ethers');
const provider = getDefaultProvider('https://data-seed-prebsc-2-s2.binance.org:8545');
const wallet = new Wallet('0xff059c1e1c2fac3d0cd2ac803d77b85a94584eab7384aa1a6e7728b5019dbb7f', provider);

const BlindBox_contractAddr = "0x8168F65274751B026d6963Cc61009af7e0faB590";

let blindBox_json = require('../../build/contracts/BlindBox.json');
const blindBox_abi = blindBox_json.abi;

const BlindBox_contractHandler = new Contract(BlindBox_contractAddr,blindBox_abi,wallet);
const GasLimit = 10500000;

//token
const contractPlatformTokenAddr = "0x7b3755F969BeFd89d7057128052bbd085858C808";
let jsonToken = require('../../build/contracts/WrappedToken.json');
const abiToken = jsonToken.abi;
const contractPlatformTokenHandler = new Contract(contractPlatformTokenAddr, abiToken, wallet);

const contractKeyTokenAddr = "0xC9F4F5766Bb0454C5B8C9F27e45AE65cBFf5ACE5";
let jsonkeyToken = require('../../build/contracts/WrappedToken.json');
const abikeyToken = jsonkeyToken.abi;
const contractKeyTokenHandler = new Contract(contractKeyTokenAddr, abikeyToken, wallet);

const flipAddr = "0x512d8a9792C4baaC5A7a8A769AaE58cAfE94B5af";

//----------------------------------------------------------------
const PrizePool_contractAddr = "0x43993Ae1270765F4bbd92D4a1133523B04c8F146";

let prizePool_json = require('../../build/contracts/PrizePool.json');
const prizePool_abi = prizePool_json.abi;

const PrizePool_contractHandler = new Contract(PrizePool_contractAddr,prizePool_abi,wallet);

async function TestMintKey(){
    try {
        console.log("-----mint----");
        let res = await BlindBox_contractHandler.MintKey("0x4936e6A6A989b4B6101D7Bd70a8e494649853360",10000000000000000,"0x48b34bcc6a6fcf84a3f6a27a943288ad7c056720",{gasLimit:GasLimit});
        console.log(res);

    } catch (e){
        console.log("err -->",e);
    }
}

async function TestPrizePoolSend(){
    try {
        console.log("-----mint----");
        const constantsOne = BigInt(1000000000000000000);
        let res = await PrizePool_contractHandler.sender("0x4936e6A6A989b4B6101D7Bd70a8e494649853360","0x8725f1aCA2a85056a81ed895Cc34CF18d8480207",constantsOne,{gasLimit:GasLimit});
        console.log(res);

    } catch (e){
        console.log("err -->",e);
    }
}

async function TestInit(){
    try {
        console.log("-----init -----");
        let initHx = await BlindBox_contractHandler.init({name:"Box Token",symbol:"Box",decimals:18,
        controller:BlindBox_contractAddr},"0x512d8a9792C4baaC5A7a8A769AaE58cAfE94B5af",{gasLimit:GasLimit});
        console.log("init hash",initHx);
    }catch (e){
        console.log("err-->",e);
    }

}


async function TestMintBox(){
    try {
        console.log("-----mint box -----");
        var level =[1,3,10,30,80];
        var draw = [5,100,1000,10000];
        var mix = [5,100,1000,10000];
        var token = [contractPlatformTokenAddr];
        var amount = [1000000000];
        let mintBoxHx = await BlindBox_contractHandler.MintBox({
            name:"hello kitty",
            series_id:1,
            types_id:2,
            draw_id:3,
            chain_id:97,
            image:"https://github.com",
            level:level,
            draw:draw,
            mix:mix,
            reward:{token:token,amount:amount}
        });
        console.log("mint box hx = ",mintBoxHx);
    }catch (e){
        console.log("err -->",e);
    }
}
async function TestQueryBox(){
    try {
        console.log("-----QueryBox----");
        let res = await BlindBox_contractHandler.QueryBox(1);
        console.log(res);
    }catch (e){
        console.log("err -->",e);
    }

}

async function TestQueryBoxs(){
    try {
        console.log("-----QueryBoxs----");
        let res = await BlindBox_contractHandler.QueryBoxs(0,10);
        console.log(res);
    }catch (e){
        console.log("err -->",e);
    }

}

async function TestDraw(){
    try {
        console.log("-----draw -----");
        const constantsOne = BigInt(10000000000000000000);
        let approveRes = await contractPlatformTokenHandler.approve(BlindBox_contractAddr,constantsOne,{gasLimit:GasLimit});
        console.log("approve===>",approveRes);

        let drawRes = await BlindBox_contractHandler.Draw(10,"0x4936e6A6A989b4B6101D7Bd70a8e494649853360",{gasLimit:GasLimit});
        console.log("draw ===> ",drawRes);

    }catch (e){
        console.log("err -->",e);
    }
}

async function TestDrawOut(){
    try {
        console.log("-----draw -----");
        const constantsOne = BigInt(10000000000000000000);
        let approveRes = await contractKeyTokenHandler.approve(BlindBox_contractAddr,constantsOne,{gasLimit:GasLimit});
        console.log("approve===>",approveRes);
        let drawOutRes = await BlindBox_contractHandler.DrawOut(1,10,{gasLimit:GasLimit});
        console.log("draw ===> ",drawOutRes);

    }catch (e){
        console.log("err -->",e);
    }
}

async function TestResetDraw(){
    try {
        console.log("-----Reset Draw Ratio -----");
        var draw = [1000,10000,1000000,100000,10000000];
        let resetDrawHx = await BlindBox_contractHandler.ResetDraw(1,draw,{gasLimit:GasLimit});
        console.log("resetDrawHx == ",resetDrawHx);
    }catch (e){
        console.log("err -->",e);
    }

}
async function TestQueryConfig(){
    try {
        console.log("-----query config-----");
        let config = await BlindBox_contractHandler.QueryConfig();
        console.log("config - ",config);
    }catch (e){
        console.log("err -->",e);
    }

}



async function main(){
    //await TestMintKey();
    // await TestInit();// done
    await TestMintBox();//done
    //await TestQueryBox();// done
    //await TestQueryBoxs();// todo
    //await TestDraw();  // done
    //await TestDrawOut(); //todo burn
    //await TestResetDraw();
    // await TestQueryConfig();
    //await TestPrizePoolSend();
}

main().catch(err =>{
    console.log("err",err);
});
