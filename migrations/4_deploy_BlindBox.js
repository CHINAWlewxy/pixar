const BlindBox = artifacts.require("BlindBox");
const BuildToken = artifacts.require("BuildToken");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const nft = artifacts.require("nft");
const PrizePool = artifacts.require("PrizePool");
const Gov = artifacts.require("Gov");
module.exports = function (deployer){
    deployer.deploy(BlindBox,
                    //owner
                    //Gov.address,
                    "0x4936e6A6A989b4B6101D7Bd70a8e494649853360",
                    "0x4Ac19Ef38DB893a9128a49C654680A5DdC3F8202",
                    WrappedPlatformToken.address,
                    BuildToken.address,
                    nft.address);
};
