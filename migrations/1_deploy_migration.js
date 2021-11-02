const Migrations = artifacts.require("Migrations");
const ControlledTokenProxyFactory = artifacts.require("ControlledTokenProxyFactory");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const BuildToken = artifacts.require("BuildToken");
const Unit = 1000000000000000000n;
module.exports = function (deployer) {
    deployer.deploy(Migrations);
    deployer.deploy(WrappedPlatformToken,
                    //mint address
                    "0x7bE211121a79e2CE079B13dA8E12b0CFdEaAC19a",
                    1000,
                    "0x4936e6A6A989b4B6101D7Bd70a8e494649853360",
                    1000n*Unit,
                    2000n*Unit);
    deployer.deploy(ControlledTokenProxyFactory).then(function(){
        return deployer.deploy(BuildToken,ControlledTokenProxyFactory.address);
    });
};
