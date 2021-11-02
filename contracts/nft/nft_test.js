const { utils } = require('ethers');
const { Contract, getDefaultProvider, Wallet,BigNumber } = require('ethers');
const provider = getDefaultProvider('https://data-seed-prebsc-1-s1.binance.org:8545');
const wallet = new Wallet('0xff059c1e1c2fac3d0cd2ac803d77b85a94584eab7384aa1a6e7728b5019dbb7f', provider);
const GasLimit = 10500000;

const contractNFTAddr = "0x96A140e8BBc2C84C2054C4795412C313386837A0";
let jsonnft = require('../../build/contracts/nft.json');
const abinft = jsonnft.abi;
const contractnftHandler = new Contract(contractNFTAddr, abinft, wallet);

const name_= 'Hello';
const symbol = 'PG';
const seriesId = 8888;
const S_number = 2;
const A_number = 2;
const B_number = 2;
const C_number = 2;
const D_number = 2;
const S_Pr = 25;
const A_Pr = 25;
const B_Pr = 25;
const C_Pr = 25;
const A_composePr = 38;
const B_composePr = 10000;
const C_composePr = 20;
const D_composePr = 50;


async function TestMintNFT(){
    try {
        console.log("-----Draw----");
        // let res = await contractnftHandler.Draw("0xEdd7180D9356895E833c4781cF2733af76CC3A50",10,0,seriesId,
        // [S_Pr,A_Pr,B_Pr,C_Pr],[S_number,A_number,B_number,C_number,D_number],{gasLimit:GasLimit});
        
        // // let res = await contractnftHandler.setUrI(0);
        // // let res = await contractnftHandler.tokenURI(0);
        // // let res = await contractnftHandler.getAddrAllTokenIds("0xEdd7180D9356895E833c4781cF2733af76CC3A50",)
        // console.log(res);

        // let bl = await contractnftHandler.balanceOf("0xEdd7180D9356895E833c4781cF2733af76CC3A50");
        // console.log("accounts[1] balanceOf: %d", bl);

        // let ntfInfo_1 = await contractnftHandler.getNftInfo(1);
        // console.log("NFT_tokenID = 1 : series=>%s,TypeNumber=>%s,grade=>%s,ID=>%s," ,ntfInfo_1.tSerialNumber,
        // ntfInfo_1.tTypeNumber,ntfInfo_1.tGrade,ntfInfo_1.tGradeId);

        // let ntfInfo_2 = await contractnftHandler.getNftInfo(0);
        // console.log("NFT_tokenID = 0 : series=>%s,TypeNumber=>%s,grade=>%s,ID=>%s," ,ntfInfo_2.tSerialNumber,
        // ntfInfo_2.tTypeNumber,ntfInfo_2.tGrade,ntfInfo_2.tGradeId);
        
        let tokenIdArray = await contractnftHandler.getAddrAllTokenIds("0xEdd7180D9356895E833c4781cF2733af76CC3A50",10,1);
        console.log("accounts[1] all tokenId: " ,tokenIdArray);
    } catch (e){
        console.log("err -->",e);
    }
}

const formatBignumber = (num)=>{
    num = num.toString()
    return utils.parseUnits(num,18)
}

async function TestComposeNFT(){
    try {
        console.log("-----compose----");
        let res = await contractnftHandler.gradeCompose("0xEdd7180D9356895E833c4781cF2733af76CC3A50",
        8888,[A_composePr,B_composePr,C_composePr,D_composePr],[S_number,A_number,B_number,C_number,D_number],
        5,[0,1,2,3,5],"12",{gasLimit:GasLimit});
        console.log(res);
    } catch (e){
        console.log("err -->",e);
    }
}

async function TestCashNFT(){
    try {
        console.log("-----cash----");
        let res = await contractnftHandler.cashCheck("0xEdd7180D9356895E833c4781cF2733af76CC3A50",seriesId,[S_number,A_number,B_number,C_number,D_number],
        {gasLimit:GasLimit});
    } catch (e){
        console.log("err -->",e);
    }
}

async function TestInit(){
    try {
        let getLinkRand = await contractnftHandler.getLinkRand();
        console.log("========getLinkRand========",getLinkRand);
        console.log("-----init----");
        let res = await contractnftHandler.init("0x8168F65274751B026d6963Cc61009af7e0faB590","0x512d8a9792C4baaC5A7a8A769AaE58cAfE94B5af","0xEdd7180D9356895E833c4781cF2733af76CC3A50",{gasLimit:GasLimit});
        console.log(res);
    } catch (e){
        console.log("err -->",e);
    }
}

async function main(){
    // await TestMintNFT();
    // await TestComposeNFT();
    // await TestCashNFT();
    await TestInit();
}

main().catch(err =>{
    console.log("err",err);
});
