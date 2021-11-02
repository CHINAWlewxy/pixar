const { utils } = require("ethers");
const { Contract, getDefaultProvider, Wallet, BigNumber } = require("ethers");
const provider = getDefaultProvider(
  "https://data-seed-prebsc-1-s1.binance.org:8545/"
);
let private_key =
  // "0x6271102e8b770eea39b241054fb793fb94a22c24ab949af01c9c661d53445ccc";
  "19b7f26c0f14c102bdcbb01cfd7607f6d5d92482d5b1eedc103d83a550af9dc3";
let private_key_new =
  "0x6271102e8b770eea39b241054fb793fb94a22c24ab949af01c9c661d53445ccc";
const wallet = new Wallet(private_key, provider);
const wallet_new = new Wallet(private_key_new, provider);

let json = require("../../build/contracts/Lock.json");
const abi = json.abi;
const contractAddr = "0x8395e2cddb5457a4a70bd240da2fb6be55285dbe";
const contractHandler = new Contract(contractAddr, abi, wallet);
const contractHandler_new = new Contract(contractAddr, abi, wallet_new);

let jsonToken = require("../../build/contracts/WrappedToken.json");
const abiToken = jsonToken.abi;
//Platform token
const contractPlatformTokenAddr = "0x68Fa60737e8Fef9B478d0d253818FA9be307649C";
const contractPlatformTokenHandler = new Contract(
  contractPlatformTokenAddr,
  abiToken,
  wallet
);
//Usdt token
const contractUsdtTokenAddr = "0x95d3eeeD6949bBe5Bca8a35F7e39CA0eAd3ECC15";
const contractUsdtTokenHandler = new Contract(
  contractUsdtTokenAddr,
  abiToken,
  wallet
);

const Unit = 1000000000000000000n;
const PriceUnit = 10000000000n;

const GasLimit = 10500000;

async function sleep(ms = 0) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

async function aprovePlatform(amount) {
  try {
    await contractPlatformTokenHandler.approve(contractAddr, amount, {
      gasLimit: GasLimit,
    });
    console.log("✓---------- aprovePlatform -----------");
  } catch (e) {
    console.log("❌================ aprovePlatform ====================");
    console.log(e.message);
  }
}

async function aproveUsdt(amount) {
  try {
    await contractUsdtTokenHandler.approve(contractAddr, amount, {
      gasLimit: GasLimit,
    });
    console.log("✓---------- aproveUsdt -----------");
  } catch (e) {
    console.log("❌================ aproveUsdt ====================");
    console.log(e.message);
  }
}

async function Test_QueryConfig() {
  try {
    console.log("----------- Test_QueryConfig start -----------");
    let config = await contractHandler.QueryConfig();
    console.log("owner:", config.owner);
    console.log("platform_token:", config.platform_token);
    console.log(
      "periodDuration:",
      config.periodDuration
    );
    console.log("rewardsDuration:", config.rewardsDuration);
    console.log("lockDuration:", config.lockDuration);
    console.log("periodNumber:", config.periodNumber);
    console.log("donate:", config.donate);
    console.log("✓---------- Test_QueryConfig end   -----------");
  } catch (e) {
    console.log("❌================ Test_QueryConfig ====================");
    console.log(e.message);
  }
}

async function Test_rewardData() {
  try {
    console.log("----------- rewardData start -----------");
    let idx = await contractHandler.GetPeriodInd();
    let ret = await contractHandler.rewardData(idx);
    console.log("reward：", ret);
    console.log("✓---------- rewardData end   -----------");
  } catch (e) {
    console.log("❌================ rewardData ====================");
    console.log(e.message);
  }
}

async function Test_ClaimableRewards() {
  try {
    console.log("----------- ClaimableRewards start -----------");
    let account = "0x44f03800aa2776c6c08ebfe07eb0c0ba89174fbd";
    let ret = await contractHandler.ClaimableRewards(account);
    console.log("Total Awards:", ret.total);
    for (let i = 0; i < ret.claRewards.length; i++) {
      console.log(i + 1, "//////////////////////////////");
      console.log("Reward cycle:", ret.claRewards[i].idx);
      console.log("Number of awards:", ret.claRewards[i].amount);
    }
    console.log("✓---------- ClaimableRewards end   -----------");
  } catch (e) {
    console.log("❌================ ClaimableRewards ====================");
    console.log(e.message);
  }
}

async function Test_GetStakeAmounts() {
  try {
    console.log("----------- GetStakeAmounts start -----------");
    let account = "0x44f03800aa2776c6c08ebfe07eb0c0ba89174fbd";
    let ret = await contractHandler.GetStakeAmounts(account);
    console.log("Total mortgage:", ret.total);
    console.log("Desirable mortgage:", ret.unlockable);
    console.log("No mortgage:", ret.locked);
    for (let i = 0; i < ret.lockData.length; i++) {
      console.log(i + 1, "//////////////////////////////");
      console.log("Reward cycle:", ret.lockData[i].idx);
      console.log("Number of awards:", ret.lockData[i].amount);
    }
    console.log("✓---------- GetStakeAmounts end   -----------");
  } catch (e) {
    console.log("❌================ GetStakeAmounts ====================");
    console.log(e.message);
  }
}

async function Test_RewardToken() {
  try {
    let ret = await contractHandler.RewardToken({ gasLimit: GasLimit });
    console.log(ret);
    console.log("✓---------- Test_RewardToken end   -----------");
  } catch (e) {
    console.log("❌================ Test_RewardToken ====================");
    console.log(e.message);
  }
}

async function Test_LockToken() {
  try {
    let ret = await contractHandler.Stake({ gasLimit: GasLimit });
    console.log(ret);
    console.log("✓---------- Test_LockToken end   -----------");
  } catch (e) {
    console.log("❌================ Test_LockToken ====================");
    console.log(e.message);
  }
}

async function Test_GetReward() {
  try {
    console.log("----------- GetReward start -----------");
    let account = "0x44f03800aa2776c6c08ebfe07eb0c0ba89174fbd";
    let ret = await contractHandler.GetReward(0, 100);
    console.log("✓---------- GetReward end   -----------", ret);
  } catch (e) {
    console.log("❌================ GetStakeAmounts ====================");
    console.log(e.message);
  }
}

async function Test_WithdrawExpiredLocks() {
  try {
    console.log("----------- Test_WithdrawExpiredLocks start -----------");
    let account = "0x44f03800aa2776c6c08ebfe07eb0c0ba89174fbd";
    let ret = await contractHandler.WithdrawExpiredLocks(0, 100);
    console.log("✓---------- Test_WithdrawExpiredLocks end   -----------", ret);
  } catch (e) {
    console.log("❌================ GTest_WithdrawExpiredLocks ====================");
    console.log(e.message);
  }
}

async function Test_userRewards() {
  try {
    console.log("----------- Test_userRewards start -----------");
    let account = "0x44f03800aa2776c6c08ebfe07eb0c0ba89174fbd";
    let ret = await contractHandler.userRewards(account, 1);
    console.log("✓---------- Test_userRewards end   -----------", ret);
  } catch (e) {
    console.log("❌================ Test_userRewards ====================");
    console.log(e.message);
  }
}

async function main() {
  console.log("contractAddr:", contractAddr);
  // await Test_QueryConfig();
  // await Test_ClaimableRewards()
  // await Test_GetStakeAmounts();
  // await Test_GetReward();
  // await Test_WithdrawExpiredLocks();
  // await Test_rewardData()
  // await aprovePlatform(1000n * Unit);
  // await aproveUsdt(100n * Unit);
  // await Test_LockToken();
  // await Test_RewardToken();
  await Test_userRewards()
}

main().catch((err) => {
  console.log("error", err);
});
