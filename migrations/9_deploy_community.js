const Community = artifacts.require("Community");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const Gov = artifacts.require("Gov");
const Unit = 1000000000000000000n;
module.exports = function (deployer) {
  deployer.deploy(
    Community,
    Gov.address,
    WrappedPlatformToken.address,
    50000000n * Unit
  );
};
