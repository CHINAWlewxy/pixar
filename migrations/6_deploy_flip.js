const flip = artifacts.require("flip");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const nft = artifacts.require("nft");
const BlindBox = artifacts.require("BlindBox");
const Gov = artifacts.require("Gov");
const PrizePool = artifacts.require("PrizePool");
module.exports = function (deployer){
    deployer.deploy(flip,
                    // owner
                    //Gov.address,
                    // fee
                    "0x36b398c09b130b558C23AB94b4146f8911D6a8f1",
                    // platform
                    WrappedPlatformToken.address,
                    // nft
                    nft.address,
                    // blindbox
                    BlindBox.address,
                    PrizePool.address,
                    
                    //bscscan_Test
                    "0xa555fC018435bef5A13C6c6870a9d4C11DEC329C", //_vrfCoordinator 
                    "0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06", //_linkToken
                    "0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186",//_keyHash
                    "100000000000000000" //_fee

                    // //bscscan_Main
                    // "0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31", //_vrfCoordinator 
                    // "0x404460C6A5EdE2D891e8297795264fDe62ADBB75", //_linkToken
                    // "0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c",//_keyHash
                    // "200000000000000000" //_fee
                    );
};
