const PrizePool = artifacts.require("PrizePool");
const Gov = artifacts.require("Gov");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const BlindBox = artifacts.require("BlindBox");
module.exports = function (deployer) {
    deployer.deploy(PrizePool,
                    //blindbox address
                    BlindBox.address,
                    // platform_token
                    WrappedPlatformToken.address,
                    // panacke_router address
                    "0xF4Ef3071c9c16D0103393eCe00fA980Aa419dAA0",
                    // wbnb_address
                    "0x89ff1CF4fbBDD4cd5adB3C0FE67BdBBf30f6454c",
                    // cake min reward
                    3,
                    //gov address
                    Gov.address,
                    // cake address
                    "0x0986F28e36C0d27FFe9a9d08261B9490004dbAc8"
                   );
};
