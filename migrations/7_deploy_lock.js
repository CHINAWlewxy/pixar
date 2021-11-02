const Lock = artifacts.require("Lock");
const BlindBox = artifacts.require("BlindBox");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const nft = artifacts.require("nft");

module.exports = function (deployer) {
  deployer.deploy(
      Lock,
      WrappedPlatformToken.address,
      86400 * 7,
      86400 * 7 * 13, 
      86400 * 7 * 13, 
      nft.address,
      BlindBox.address
  );
};
