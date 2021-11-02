pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../token/WrappedToken.sol";
import "../TransferHelper.sol";
import "../nft/nft.sol";
import "../blindBox/BlindBox.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "../ItokenId/ItokenId.sol";

contract Lock {
    using SafeMath for uint256;

    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 public constant ONE_NFT_REWARD_AMOUNT = 1000 * (10**18);

    uint256 public constant MAX_NFT_REWARD = 20;
    uint256 public startTime = 0;

    uint256 lastRewardNFTId;
    Config public config;
    uint256 public currentIdx;
    mapping(uint256 => Reward) public rewardData;
    // user -> idx -> amount
    mapping(address => mapping(uint256 => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(uint256 => uint256)) public rewards;
    mapping(address => RewardBalance[]) public userRewards;

    mapping(address => Balances) public balances;
    mapping(address => LockedBalance[]) public userLocks;

    uint256 public totalRewardAmount;
    uint256 public totalCollateralAmount;
    uint256 public totalDistributeAmount;

    uint256 public totalWithdrawCollateralAmount;

    struct Config {
        WrappedToken platform_token;
        nft          nft_token;
        BlindBox     blind_box;
        uint256      periodDuration;
        uint256      rewardsDuration;
        uint256      lockDuration;
        address      iTokenId;
    }

    struct Reward {
        uint256 periodFinish;
        uint256 lockFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 collateralAmount;
        uint256 rewardAmount;
        uint256 modLeft;
    }

    struct Balances {
        uint256 total;
        // idx -> amount
        mapping(uint256 => uint256 ) stakeAmount;
    }

    struct LockedBalance {
        uint256 amount;
        uint256 idx;
    }

    struct RewardBalance {
        uint256 amount;
        uint256 idx;
    }

    struct LockedBalanceResp {
        uint256 amount;
        uint256 idx;
        bool lock;
    }

    event rewardToken(uint256 amount);
    event staked(address indexed user, uint256 amount);
    event withdrawn(address indexed user, uint256 amount);
    event rewardPaid(address indexed user, uint256 reward);

    modifier nonReentrant() {
        require(_status != _ENTERED, "Lock: nonReentrant reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _platform_token, uint256 _periodDuration, uint256
                _rewardsDuration, uint256 _lockDuration, address _nft_token,
                address payable _blind_box,address _itokenId) public {
        require(_periodDuration > 0, "Lock: _periodDuration should greater then 0");
        require(_rewardsDuration >= _periodDuration, "Lock: _rewardsDuration should greater or equal then _periodDuration");
        require(_lockDuration >= _rewardsDuration, "Lock: _lockDuration should greater or equal then _rewardsDuration");
        config.platform_token = WrappedToken(_platform_token);
        config.periodDuration = _periodDuration;
        config.rewardsDuration = _rewardsDuration;
        config.lockDuration = _lockDuration;
        config.nft_token = nft(_nft_token);
        config.blind_box = BlindBox(_blind_box);
        config.iTokenId = _itokenId;
        currentIdx = GetPeriodInd();
        startTime = block.timestamp;
        rewardData[currentIdx].lastUpdateTime = startTime;
        rewardData[currentIdx].periodFinish = startTime + config.rewardsDuration;
        rewardData[currentIdx].lockFinish = startTime + config.lockDuration;
        lastRewardNFTId = 10000000;
    }

    function RewardToken(uint256 amount) external nonReentrant {
        updateReward(address(0), currentIdx);
        // uint256 amount = config.platform_token.allowance(msg.sender, address(this));
        require(amount > 0, "Lock: RewardToken wrong asset");
        TransferHelper.safeTransferFrom(address(config.platform_token), msg.sender, address(this), amount);

        Reward storage rewardRef = rewardData[currentIdx];
        rewardRef.rewardAmount = rewardRef.rewardAmount.add(amount);

        uint256 remaining = rewardRef.periodFinish.sub(block.timestamp);
        uint256 leftover = remaining.mul(rewardRef.rewardRate);
        totalRewardAmount = totalRewardAmount.add(amount);
        amount = amount.add(leftover).add(rewardRef.modLeft);
        rewardRef.rewardRate = amount.div(remaining);
        rewardRef.modLeft = amount.mod(remaining);
        emit rewardToken(amount);
    }

    function Stake(uint256 amount) external nonReentrant {
        require(msg.sender == tx.origin,"Lock Err:request failed");
        updateReward(msg.sender, currentIdx);
        // uint256 amount = config.platform_token.allowance(msg.sender, address(this));
        require(amount > 0, "Lock: stake Cannot stake 0");

        Balances storage bal = balances[msg.sender];
        bal.total = bal.total.add(amount);
        bal.stakeAmount[currentIdx] = bal.stakeAmount[currentIdx].add(amount);

        LockedBalance[] storage locks = userLocks[msg.sender];
        uint256 len = locks.length;
        if (len > 0 && currentIdx == locks[len-1].idx) {
            locks[len-1].amount = locks[len-1].amount.add(amount);
        } else {
            locks.push(LockedBalance({amount: amount, idx: currentIdx}));
        }

        rewardData[currentIdx].collateralAmount = rewardData[currentIdx].collateralAmount.add(amount);
        totalCollateralAmount = totalCollateralAmount.add(amount);

        TransferHelper.safeTransferFrom(address(config.platform_token), msg.sender, address(this), amount);
        uint256 nftRewardCnt = amount / ONE_NFT_REWARD_AMOUNT;
        if (nftRewardCnt > 0) {
            if (nftRewardCnt > MAX_NFT_REWARD) {
                nftRewardCnt = MAX_NFT_REWARD;
            }
            (uint256[] memory seriesIds, uint256 lenId) = config.blind_box.QuerySeriesIdsNotNull();
            uint256 randNumber =  ItokenId(config.iTokenId).getRandomNumber(msg.data, msg.sender);
             for (uint256 i = 0; i < nftRewardCnt; i++) {
                 uint256 randSeridId = randNumber % lenId;
                 uint256 rander =  uint256(keccak256(abi.encodePacked(randNumber,i)));
                config.nft_token.Draw(msg.sender, 1, 0, seriesIds[randSeridId],
                                      rander);
             }
        }
        emit staked(msg.sender, amount);
    }

    function GetReward() public nonReentrant{
        //require(_start < _end, "GetReward: arg1 must less than arg2");
        LockedBalance[] storage locks = userLocks[msg.sender];
        uint256 length = locks.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 idx = locks[i].idx;
            updateReward(msg.sender, idx);
        }

        RewardBalance[] storage userReward = userRewards[msg.sender];
        mapping(uint256 => uint256) storage bal = rewards[msg.sender];
        uint256 amount = 0;
        length = userReward.length;
        if (length == 0) {
            return;
        }
        uint256 i = 0;
        for (; i < length; i++) {
            uint256 idx = userReward[i].idx;
            amount = amount.add(userReward[i].amount);
            delete userReward[i];
            delete bal[idx];
        }
        if (i == length) {
            delete userRewards[msg.sender];
        }
        totalDistributeAmount = totalDistributeAmount.add(amount);
        TransferHelper.safeTransfer(address(config.platform_token), msg.sender, amount);
        emit rewardPaid(msg.sender, amount);
    }

    function WithdrawExpiredLocks(uint256 _start, uint256 _end) external {
        GetReward();
        LockedBalance[] storage locks = userLocks[msg.sender];
        Balances storage bal = balances[msg.sender];
        uint256 amount = 0;
        uint256 length = locks.length;
        if (locks.length < _end) {
            _end = locks.length;
        }
        if (length == 0) {
            return;
        }
        // require(length > 0, "Lock: WithdrawExpiredLocks is 0");
        uint256 idx = locks[length-1].idx;
        uint256 unlockTime = rewardData[idx].lockFinish;
        if (_start == 0 && length == locks.length && unlockTime <= block.timestamp) {
            amount = bal.total;
            bal.total = 0;
            for (uint256 i = 0; i < length; i++) {
                idx = locks[i].idx;
                delete bal.stakeAmount[idx];
            }
            delete userLocks[msg.sender];
        } else {
            for (uint256 i = _start; i < _end; i++) {
                idx = locks[i].idx;
                unlockTime = rewardData[idx].lockFinish;
                if (unlockTime > block.timestamp) break;
                amount = amount.add(locks[i].amount);
                bal.total = bal.total.sub(locks[i].amount);
                delete locks[i];
                delete bal.stakeAmount[idx];
            }
        }
        if (amount == 0) {
            return;
        }
        // require(amount > 0, "Lock: WithdrawExpiredLocks is 0");
        totalWithdrawCollateralAmount = totalWithdrawCollateralAmount.add(amount);
        TransferHelper.safeTransfer(address(config.platform_token), msg.sender, amount);
    }

    function QueryConfig() external view returns (Config memory) {
        return config;
    }

    function GetPeriodInd() public view returns (uint256) {
        return 1 + block.timestamp.sub(startTime).div(config.periodDuration);
    }

    function ClaimableRewards(address user) external view returns (uint256 total, RewardBalance[] memory claRewards) {
        LockedBalance[] storage locks = userLocks[user];
        claRewards = new RewardBalance[](locks.length);
        uint256 length = locks.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 idx = locks[i].idx;
            uint256 amount = _earned(user, idx);
            total = total.add(amount);
            claRewards[i].amount = amount;
            claRewards[i].idx = idx;
        }
    }

    function GetStakeAmounts(address user) external view returns (uint256 total, uint256 unlockable,
        uint256 locked, LockedBalanceResp[] memory lockData) {
        LockedBalance[] storage locks = userLocks[user];
        lockData = new LockedBalanceResp[](locks.length);
        for (uint256 i = 0; i < locks.length; i++) {
            uint256 idx = locks[i].idx;
            uint256 unlockTime = rewardData[idx].lockFinish;
            if (unlockTime > block.timestamp) {
                locked = locked.add(locks[i].amount);
                lockData[i].lock = true;
            } else {
                unlockable = unlockable.add(locks[i].amount);
                lockData[i].lock = false;
            }
            lockData[i].amount = locks[i].amount;
            lockData[i].idx = locks[i].idx;
        }
        return (balances[user].total, unlockable, locked, lockData);
    }

    function TotalStake() view external returns (uint256 total) {
        uint256 periodFinish = startTime + block.timestamp.sub(startTime).div(config.periodDuration).mul(config.periodDuration);
        uint256 idx = GetPeriodInd();

        Reward storage data = rewardData[idx];
        total = total.add(data.collateralAmount);
        while (data.periodFinish > periodFinish && idx > 0) {
            data = rewardData[--idx];
            total = total.add(data.collateralAmount);
        }
    }

    function TotalAllStake() view external returns (uint256) {
        return totalCollateralAmount - totalWithdrawCollateralAmount;
    }

    function LastTimeRewardApplicable(uint256 idx) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[idx].periodFinish);
    }

    function RewardPerToken(uint256 idx) external view returns (uint256) {
        return _rewardPerToken(idx);
    }

    function updateReward(address account, uint256 idx) internal {
        rewardData[idx].rewardPerTokenStored = _rewardPerToken(idx);
        rewardData[idx].lastUpdateTime = LastTimeRewardApplicable(idx);
        if (account != address(0)) {
            rewards[account][idx] = _earned(account, idx);
            RewardBalance[] storage rewardBalance = userRewards[account];
            uint256 len = rewardBalance.length;
            if (len > 0 && rewardBalance[len-1].idx == idx) {
                rewardBalance[len-1].amount = rewards[account][idx];
            } else {
                rewardBalance.push(RewardBalance({amount: rewards[account][idx], idx: idx}));
            }
            userRewardPerTokenPaid[account][idx] = rewardData[idx].rewardPerTokenStored;
        }

        idx = GetPeriodInd();
        if (idx != currentIdx) {
            currentIdx = idx;
            delete rewardData[idx];
            rewardData[idx].lastUpdateTime = block.timestamp;
            rewardData[idx].periodFinish = startTime + block.timestamp.sub(startTime).div(config.periodDuration).mul(config.periodDuration).add(config.rewardsDuration);
            rewardData[idx].lockFinish = startTime + block.timestamp.sub(startTime).div(config.periodDuration).mul(config.periodDuration).add(config.lockDuration);
        }
    }

    function _earned(
        address _user,
        uint256 idx
    ) internal view returns (uint256) {
        Balances storage bal = balances[_user];
        return bal.stakeAmount[idx].mul(
            _rewardPerToken(idx).sub(userRewardPerTokenPaid[_user][idx])
        ).div(1e18).add(rewards[_user][idx]);
    }

    function _rewardPerToken(uint256 idx) internal view returns (uint256) {
        uint256 supply = rewardData[idx].collateralAmount;
        if (supply == 0) {
            return rewardData[idx].rewardPerTokenStored;
        }
        return rewardData[idx].rewardPerTokenStored.add(
                LastTimeRewardApplicable(idx).sub(
                    rewardData[idx].lastUpdateTime).mul(
                        rewardData[idx].rewardRate).mul(1e18).div(supply)
            );
    }
}
