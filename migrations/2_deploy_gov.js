const Gov = artifacts.require("Gov");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");

const Unit = 1000000000000000000n;

module.exports = function (deployer) {
  deployer.deploy(
    Gov,
    "0x4936e6A6A989b4B6101D7Bd70a8e494649853360", //owner
    WrappedPlatformToken.address,
    1000n, //quorum
    5000n, //threshold
    20n, 
    20n, 
    20n, 
    100n * Unit 
  );
};
