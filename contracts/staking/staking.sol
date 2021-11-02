pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "../token/WrappedToken.sol";
import "../lock/lock_contract.sol";
import "../TransferHelper.sol";
contract Staking{
   using SafeMath for uint256;

   uint256 public constant DISTRIBUTION_INTERVAL = 60;

   struct Config{
       address owner;
       address platform_token;
       address staker_donate;
   }

   bool public unregister_platform_asset = true;

   Config public config;
   Distribute public distribute;
   constructor (address _owner,
                address _platform_token,
                address _staker_donate,
                uint256 _distrbiute_amount)public{
       config.owner = _owner;
       config.platform_token = _platform_token;
       config.staker_donate = _staker_donate;
       distribute.amount = _distrbiute_amount;
       distribute.last = now;
   }

   struct PoolInfo{
       address asset_token;
       address staking_token;
       uint256 pending_reward;
       uint256 total_bond_amount;
       uint256 reward_index;
   }

   struct StakeRewardResponse{
       address staking_token;
       uint256 pending_reward;
   }

   struct RewardInfoResponse{
       address staker;
       address asset_token;
       uint256 index;
       uint256 bond_amount;
       uint256 pending_reward;
   }

   struct PoolInfoResponse{
       address asset_token;
       address staking_token;
       uint256 total_bond_amount;
       uint256 reward_index;
       uint256 pending_reward;
   }

   struct RewardInfo {
       uint256 index;
       uint256 bond_amount;
       uint256 pending_reward;
   }

   struct Distribute{
       uint256 last;
       uint256 amount;
       //address usdt_platform_lptoken;
   }


   function QueryDistribute() external view returns (Distribute memory){
       return distribute;
   }

   event distribute_log(uint256,uint256);

   function Distributer() external {
       require(distribute.last + DISTRIBUTION_INTERVAL < now,"Staking: Distribute Cannot distribute platform token before interval");
       uint256 time_elapsed = now.sub(distribute.last);
       uint256 lp_lens = lp_list.length;
       uint256 amount = time_elapsed.mul(distribute.amount).div(lp_lens);
       //ques : all or only platform ?
       if (amount > 0){
           for (uint256 i = 0; i < lp_lens;i++){
               depositReward(lp_list[i], amount);
           }
       }
       distribute.last = distribute.last.add(time_elapsed);
       emit distribute_log(amount,distribute.last);
   }

   struct itmap{
       mapping(address => RewardInfo) reward;
       address[] user_bonds;
   }

   mapping (address => itmap) user_lps_reward;
   mapping(address => PoolInfo) public lp_poolInfo;
   address[] lp_list;

   event register_asset_log(address,address);
   event register_platform_asset_log(address);
   event bond_log(address , uint256);
   event unbond_log(address,uint256);
   event withdraw_log(address,uint256);
   event deposit_reward_log  (address , uint256);
   event update_config_log(address);
   event staker_log(address,uint256);

   function UpdateConfig(address _owner,address _staker_donate) external {
       require(config.owner == msg.sender,"Staking: UpdateConfig Unauthoruzed");
       config.owner = _owner;
       config.staker_donate = _staker_donate;
       emit update_config_log(_owner);
   }

   function registerPlatformAsset(address _platform_token,address _lp_token)external{
       //require(config.owner == msg.sender,"Staking: RegisterAsset Unauthoruzed");
       require(lp_poolInfo[_lp_token].staking_token == address(0),"Staking: Platform Asset was already registered");
       require(unregister_platform_asset,"Staking: Can only call once");
       require(config.platform_token == _platform_token,"Staking: Platform Not expected address");
       lp_poolInfo[_lp_token].asset_token = _platform_token;
       lp_poolInfo[_lp_token].staking_token = _lp_token;
       unregister_platform_asset = false;
       //distribute.usdt_platform_lptoken = _platform_token;
       lp_list.push(_lp_token);
       emit register_platform_asset_log(_lp_token);
   }

   function Bond(address _lp_token) external{
       PoolInfo storage _pool_info = lp_poolInfo[_lp_token];
       require(_pool_info.asset_token != address(0),"Staking: Bond Staking Token Not Found!");
       RewardInfo storage _reward_info = user_lps_reward[msg.sender].reward[_lp_token];
       WrappedToken collateral_token = WrappedToken(_lp_token);
       uint256 amount = collateral_token.allowance(msg.sender,address(this));
       TransferHelper.safeTransferFrom(_lp_token,msg.sender,address(this),amount);
       _itmap_insert(msg.sender,_lp_token);
       _before_share_change(_pool_info,_reward_info);
       _increase_bond_amount(_pool_info,_reward_info,amount);
       emit bond_log(_lp_token,amount);
   }

   function depositReward(address _staking_lp_token,uint256 amount) internal {
       PoolInfo storage _pool_info = lp_poolInfo[_staking_lp_token];
       require(_pool_info.asset_token != address(0),"Staking: Staking Token Not Found!");
       if (_pool_info.total_bond_amount == 0){
           _pool_info.pending_reward = SafeMath.add(_pool_info.pending_reward,
                                                    amount);
       }else{
           uint256 reward_per_bond = SafeMath.div(
                                                  SafeMath.add(_pool_info.pending_reward,amount)*1e18
                                                  ,_pool_info.total_bond_amount);
            _pool_info.reward_index = SafeMath.add(_pool_info.reward_index,
                                                    reward_per_bond);
            _pool_info.pending_reward = 0;
       }
       emit deposit_reward_log(_staking_lp_token,amount);
   }


   function Unbond(address _lp_token,uint256 amount)external{
       PoolInfo storage _pool_info = lp_poolInfo[_lp_token];
       require(_pool_info.staking_token != address(0),"Staking: Unbond lp_token does not exist");
       itmap storage user_reward = user_lps_reward[msg.sender];
       RewardInfo storage _reward_info = user_reward.reward[_lp_token];
       require(_reward_info.bond_amount > 0 || _reward_info.pending_reward > 0,"Staking: msg.sender not find lp_token");
       require(_reward_info.bond_amount >= amount,"Staking: Cannot unbond more than bond amount");
       _before_share_change(_pool_info,_reward_info);
       _decrease_bond_amount(_pool_info,_reward_info,amount);
       if (_reward_info.pending_reward == 0 && _reward_info.bond_amount == 0){
           delete user_reward.reward[_lp_token];
           require (_itmap_remove(msg.sender,_lp_token),"Staking: Unbond Clearance lp_token failure");
       }
       TransferHelper.safeTransfer(_lp_token,msg.sender,amount);
       emit unbond_log(_lp_token,amount);
   }

   function Withdraw(address _lp_token,uint256 _start,uint256 _end) external {
        uint256 amount = 0;
        itmap storage user_reward = user_lps_reward[msg.sender];
        if (_lp_token == address(0)){
            require(_end > _start,"Staking: Withdraw all end cannot be less than the begin");
            uint256 lp_length = user_reward.user_bonds.length;
            if (_end > lp_length){
                _end = lp_length;
            }
            for (uint256 i = _start ; i < _end; i++){
                amount = 0;

                address  _user_lp = user_reward.user_bonds[i];
                RewardInfo storage _reward_info = user_reward.reward[_user_lp];
                if (_reward_info.pending_reward == 0 &&
                    _reward_info.bond_amount == 0){
                    require(_itmap_remove(msg.sender,_user_lp),"Staking:Withdraw Clearance lp_token failure");
                    _end--;
                }else{
                    PoolInfo storage _pool_info = lp_poolInfo[_user_lp];
                    require(_pool_info.staking_token != address(0),"Staking: Withdraw lp_token does not exist");
                    _before_share_change(_pool_info,_reward_info);
                    amount = amount.add(_reward_info.pending_reward);
                    _reward_info.pending_reward = 0;

                    if (amount > 0){

                        TransferHelper.safeTransfer(config.platform_token,msg.sender,amount.div(2));
                        TransferHelper.safeApprove(config.platform_token,config.staker_donate,amount.sub(amount.div(2)));
                        Lock staker_handler = Lock(config.staker_donate);
                        staker_handler.RewardToken(amount.sub(amount.div(2)));
                        emit staker_log(msg.sender,amount);
                    }
                    emit withdraw_log(_user_lp,_reward_info.bond_amount);
                    if (_reward_info.pending_reward == 0 &&
                    _reward_info.bond_amount == 0){
                        require(_itmap_remove(msg.sender,_user_lp),"Staking:Withdraw Clearance lp_token failure");
                        _end--;
                    }
                }
            }
        }else{
            PoolInfo storage _pool_info = lp_poolInfo[_lp_token];
            require(_pool_info.staking_token != address(0),"Staking: Unbond lp_token does not exist");
            require(_pool_info.staking_token == _lp_token,"Staking: WithDraw The parameter does not match the expected");
            RewardInfo storage _reward_info = user_reward.reward[_lp_token];
            require(_reward_info.bond_amount > 0 || _reward_info.pending_reward > 0,"Staking: msg.sender not find lp_token");
            _before_share_change(_pool_info,_reward_info);
            amount = amount.add(_reward_info.pending_reward);
            _reward_info.pending_reward = 0;
            if (amount > 0){

                TransferHelper.safeTransfer(config.platform_token,msg.sender,amount.div(2));

                TransferHelper.safeApprove(config.platform_token,config.staker_donate,amount.sub(amount.div(2)));

                Lock staker_handler = Lock(config.staker_donate);
                staker_handler.RewardToken(amount.sub(amount.div(2)));
                emit staker_log(msg.sender,amount);
            }
            if (_reward_info.pending_reward == 0 &&
                _reward_info.bond_amount == 0){
                require(_itmap_remove(msg.sender,_lp_token),"Staking:Withdraw Clearance lp_token failure");
            }
            emit withdraw_log(_lp_token,_reward_info.bond_amount);
        }

    }

    function QueryConfig()external view returns (Config memory result){
        return config;
    }

    function QueryPoolInfo(address _lp_token)external view returns(PoolInfoResponse memory result){
        require(_lp_token != address(0),"Staking: Can't pass in an empty address");
        require(lp_poolInfo[_lp_token].asset_token != address(0),"Staking: Staking Token address does not exist");
        PoolInfo storage poolinfo = lp_poolInfo[_lp_token];
        result.asset_token=poolinfo.asset_token;
        result.staking_token=poolinfo.staking_token;
        result.total_bond_amount=poolinfo.total_bond_amount;
        result.reward_index=poolinfo.reward_index;
        result.pending_reward=poolinfo.pending_reward;
    }


    function QueryRewardInfo(address _lp_token,address _staker)external view returns(RewardInfoResponse[] memory){
        itmap storage user_reward = user_lps_reward[_staker];

        if (user_reward.user_bonds.length <= 0){
            RewardInfoResponse[] memory result;
            return result;
        }

        if(_lp_token == address(0)){
            uint256 lptoken_len = user_reward.user_bonds.length;
            RewardInfoResponse[] memory result = new RewardInfoResponse[](lptoken_len);
            for(uint i = 0; i < lptoken_len;i++){
                address user_lp_addr = user_reward.user_bonds[i];
                RewardInfo storage _reward_info = user_reward.reward[user_lp_addr];
                result[i].staker = _staker;
                result[i].asset_token = user_lp_addr;
                result[i].index = _reward_info.index;
                result[i].bond_amount = _reward_info.bond_amount;
                result[i].pending_reward = _reward_info.pending_reward;
            }
            return result;
        }else {
            RewardInfoResponse[] memory result = new RewardInfoResponse[](1);
            RewardInfo storage _reward_info = user_reward.reward[_lp_token];
            if (_reward_info.bond_amount == 0 && _reward_info.pending_reward == 0){
                return result;
            }
            result[0].staker = _staker;
            result[0].asset_token = _lp_token;
            result[0].index = _reward_info.index;
            result[0].bond_amount = _reward_info.bond_amount;
            result[0].pending_reward = _reward_info.pending_reward;
            return result;
        }
    }


   function QueryBondReward() external view returns(StakeRewardResponse[] memory){
        itmap storage user_reward = user_lps_reward[msg.sender];
        if (user_reward.user_bonds.length == 0){
            StakeRewardResponse[] memory result;
            return result;
        }
        uint256 lptoken_len = user_reward.user_bonds.length;
        StakeRewardResponse[] memory result = new StakeRewardResponse[](lptoken_len);
        for(uint i = 0; i < lptoken_len;i++){
            address user_lp_addr = user_reward.user_bonds[i];
            RewardInfo storage _reward_info = user_reward.reward[user_lp_addr];
            PoolInfo storage _pool_info = lp_poolInfo[user_lp_addr];
            result[i].staking_token = user_lp_addr;
            uint256 _pending_reward = (_reward_info.bond_amount.mul(_pool_info.reward_index)).
                sub(_reward_info.bond_amount.mul(_reward_info.index)).div(1e18);
            result[i].pending_reward = _reward_info.pending_reward.add(_pending_reward);
        }
        return result;
   }

   function _increase_bond_amount(PoolInfo storage _pool_info,RewardInfo storage _reward_info,uint256 amount) internal {
       _pool_info.total_bond_amount = _pool_info.total_bond_amount.add(amount);
       _reward_info.bond_amount = _reward_info.bond_amount.add(amount);
   }

   function _before_share_change(PoolInfo storage _pool_info,RewardInfo storage _reward_info)internal{
       uint256 pending_reward = (_reward_info.bond_amount.mul(_pool_info.reward_index)).
           sub(_reward_info.bond_amount.mul(_reward_info.index)).div(1e18);
       _reward_info.index = _pool_info.reward_index;
       _reward_info.pending_reward = _reward_info.pending_reward.add(pending_reward);
   }

   function _decrease_bond_amount(PoolInfo storage _pool_info,RewardInfo storage _reward_info,uint256 amount) internal{
       require(_pool_info.staking_token != address(0),"Staking: _decrease_bond_amount lp_token does not exist");
       require(_reward_info.bond_amount > 0 || _reward_info.pending_reward > 0,"Staking: _decrease_bond_amount msg.sender not find lp_token");
       _pool_info.total_bond_amount = _pool_info.total_bond_amount.sub(amount);
       _reward_info.bond_amount = _reward_info.bond_amount.sub(amount);
   }

   function _itmap_insert(address _sender,address _staking_token) internal {
       itmap storage user_reward = user_lps_reward[_sender];
       if (user_reward.reward[_staking_token].pending_reward == 0 &&
           user_reward.reward[_staking_token].bond_amount == 0){
           user_reward.user_bonds.push(_staking_token);
       }
   }

   function _itmap_remove(address _sender,address _staking_token) internal returns(bool){
       itmap storage user_reward = user_lps_reward[_sender];
       require(user_reward.user_bonds.length > 0,"Staking: _itmap_remove Staker is incorrect");
       uint256 itmp_length = user_reward.user_bonds.length;
       for (uint i = itmp_length ; i >= 1 ; i--){
            if (user_reward.user_bonds[i-1] == _staking_token){
                user_reward.user_bonds[i-1] = user_reward.user_bonds[itmp_length-1];
                user_reward.user_bonds.pop();
                return true;
            }
        }
       return false;
   }
}
