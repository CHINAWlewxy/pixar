const Staking = artifacts.require("Staking");
const Lock = artifacts.require("Lock");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const Gov = artifacts.require("Gov");
const Unit = 1000000000000000000n;
module.exports = function(deployer){
    deployer.deploy(
        Staking,
        //owner
        //Gov.address,
        "0x4936e6A6A989b4B6101D7Bd70a8e494649853360",
        WrappedPlatformToken.address,
        Lock.address,
        //1s how much platform token
        1n*Unit,
    );
};
