pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../token/WrappedToken.sol";
import "../TransferHelper.sol";
import "../staking/staking.sol";

contract Gov {
    using SafeMath for uint256;

    uint256 public constant PERCENT_PRECISION = 4;

    uint256 public constant MIN_TITLE_LENGTH = 4;
    uint256 public constant MAX_TITLE_LENGTH = 64;
    uint256 public constant MIN_DESC_LENGTH = 4;
    uint256 public constant MAX_DESC_LENGTH = 256;
    uint256 public constant MIN_LINK_LENGTH = 12;
    uint256 public constant MAX_LINK_LENGTH = 128;
    uint256 public constant MAX_USER_VOTER_NUMBER = 20;
    uint256 public constant MAX_LIMIT = 30;
    Config public config;
    State public state;
    UsersItmap banks;
    PollItmap polls;
    VoterItmap voters;

    struct Config {
        address owner;
        address platform_token;
        uint256 quorum;
        uint256 threshold;
        uint256 voting_period;
        uint256 effective_delay;
        uint256 expiration_period;
        uint256 proposal_deposit;
    }
    struct State {
        uint256 poll_count;
        uint256 total_share;
        uint256 total_deposit;
    }
    struct TokenManager {
        uint256 share;
        uint256 minAmount;
        mapping(uint256 => VoterInfo) locked_balance;
        uint256[] participated_polls;
        uint256 maxIdx;
    }

    struct VoterInfo {
        address user;
        uint vote;
        uint256 balance;
    }

    struct Poll {
        uint256 id;
        address creator;
        uint status;
        uint256 yes_votes;
        uint256 no_votes;
        uint256 end_height;
        string title;
        string description;
        string link;
        address target;
        string selector;
        bytes data;
        uint256 deposit_amount;
        uint256 total_balance_at_end_poll;
    }

        //enum PollStatus { InProgress, Passed, Rejected, Executed, Expired, All }
        //enum VoteOption { Yes, No }
    uint public constant InProgress = 0;
    uint public constant Passed = 1;
    uint public constant Rejected = 2;
    uint public constant Executed = 3;
    uint public constant Expired = 4;
    uint public constant All = 5;

    uint public constant Yes = 0;
    uint public constant No = 1;

    struct PollItmap {
        mapping(uint256 => PollIndexValue) data;
        PollsKeyFlag[] keys;
        uint256 size;
    }
    struct PollIndexValue {
        uint256 keyIndex;
        Poll value;
    }
    struct PollsKeyFlag {
        uint256 key;
        bool deleted;
    }

    struct UsersItmap {
        mapping(address => UsersIndexValue) data;
        UsersKeyFlag[] keys;
        uint256 size;
    }

    struct UsersIndexValue {
        uint256 keyIndex;
        TokenManager value;
    }

    struct UsersKeyFlag {
        address key;
        bool deleted;
    }

    struct VoterItmap {
        mapping(uint256 => VoterIndexValue) data;
        VotersKeyFlag[] keys;
        uint256 size;
    }

    struct VoterIndexValue {
        uint256 keyIndex;
        VoterManager value;
    }

    struct VotersKeyFlag {
        uint256 key;
        bool deleted;
    }

    struct VoterManager {
        address[] user;
        uint[] vote;
        uint256[] balance;
    }


    struct StakerResponse {
        uint256 balance;
        uint256 share;
        voteResp[] locked_balance;
        uint256 maxIdx;
    }

    struct voteResp {
        uint256 poll_id;
        VoterInfo value;
    }


    event create_poll(address _creator, uint256 _poll_id, uint256 _end_height);
    event update_config(address _owner, address _platform_token, uint256 _quorum,
        uint256 _threshold, uint256 _voting_period,
        uint256 _effective_delay, uint256 _expiration_period,
        uint256 _proposal_deposit);
    event stake_voting_token(address _user, uint256 _amount);
    event withdraw_voting_tokens(address _user, uint256 _amount);
    event cast_vote(address _user, uint256 _poll_id, uint vote, uint256 _amount);
    event to_binary(address,uint256);
    event end_poll_log(uint256,string,bool);
    event execute_log(uint256);
    event expire_log(uint256);

    modifier assertPercent(uint256 _percent) {
        require( _percent <= 1 * (10**PERCENT_PRECISION),
            "Gov: percent must be smaller than 1");
        _;
    }

    function assertTitle(string memory _title) pure private {
        uint256 titleLen = bytes(_title).length;
        require( titleLen >= MIN_TITLE_LENGTH,
            "Gov: title length must be grater than MIN_TITLE_LENGTH");
        require( titleLen <= MAX_TITLE_LENGTH,
            "Gov: title length must be small than MAX_TITLE_LENGTH");
    }

    function assertDesc(string memory _desc) pure private {
        uint256 descLen = bytes(_desc).length;
        require( descLen >= MIN_DESC_LENGTH,
            "Gov: desc length must be grater than MIN_DESC_LENGTH");
        require( descLen <= MAX_DESC_LENGTH,
            "Gov: desc length must be small than MAX_DESC_LENGTH");
    }

    function assertLink(string memory _link) pure private {
        uint256 linkLen = bytes(_link).length;
        require( linkLen >= MIN_LINK_LENGTH,
            "Gov: link length must be grater than MIN_LINK_LENGTH");
        require( linkLen <= MAX_LINK_LENGTH,
            "Gov: link length must be small than MAX_LINK_LENGTH");
    }


    constructor(address _owner, address _platform_token, uint256 _quorum,
        uint256 _threshold, uint256 _voting_period,
        uint256 _effective_delay, uint256 _expiration_period,
        uint256 _proposal_deposit) public
    assertPercent(_quorum) assertPercent(_threshold) {
        config.owner = _owner;
        config.platform_token = _platform_token;
        config.quorum = _quorum;
        config.threshold = _threshold;
        config.voting_period = _voting_period;
        config.effective_delay = _effective_delay;
        config.expiration_period = _expiration_period;
        config.proposal_deposit = _proposal_deposit;
    }
    function UpdateConfig(address _owner, address _platform_token, uint256 _quorum,
        uint256 _threshold, uint256 _voting_period,
        uint256 _effective_delay, uint256 _expiration_period,
        uint256 _proposal_deposit
    ) external assertPercent(_quorum) assertPercent(_threshold) {
        require(config.owner == msg.sender, "Gov UpdateConfig: unauthorized");
        config.owner = _owner;
        config.platform_token = _platform_token;
        config.quorum = _quorum;
        config.threshold = _threshold;
        config.voting_period = _voting_period;
        config.effective_delay = _effective_delay;
        config.expiration_period = _expiration_period;
        config.proposal_deposit = _proposal_deposit;
        emit update_config(_owner, _platform_token, _quorum, _threshold,
            _voting_period, _effective_delay, _expiration_period,
            _proposal_deposit);
    }

    function Init(address _platform_lp,
        address _staking_addr)external{
        require(msg.sender == config.owner,"Gov Err: unauthorized");
        Staking(_staking_addr).registerPlatformAsset(config.platform_token,_platform_lp);
    }

    function CreatePoll(uint256 _deposit_amount, string calldata _title,
        string calldata _description, string calldata _link, address _target,
        string calldata _selector, bytes calldata _data
    ) external {
        assertTitle(_title);
        assertDesc(_description);
        assertLink(_link);
        require(_deposit_amount >= config.proposal_deposit,
            "Gov CreatePoll: Must deposit more than proposal token");
        TransferHelper.safeTransferFrom(config.platform_token, msg.sender,
                                        address(this), _deposit_amount);
        state.poll_count += 1;
        state.total_deposit += _deposit_amount;

        uint256 poll_id = state.poll_count;

        Poll memory poll;
        poll.id = poll_id;
        poll.creator = msg.sender;
        poll.status = InProgress;
        poll.yes_votes = 0;
        poll.no_votes = 0;
        poll.end_height = block.number + config.voting_period;
        poll.title = _title;
        poll.description = _description;
        poll.link = _link;
        poll.target = _target;
        poll.selector = _selector;
        poll.data = _data;
        poll.deposit_amount = _deposit_amount;
        poll.total_balance_at_end_poll = 0;

        _polls_itmap_insert_or_update( poll_id, poll);
        emit create_poll(msg.sender, poll_id, block.number +
            config.voting_period);
    }

    function StakeVotingTokens(uint256 _amount) external {
        require(_amount > 0, "Gov StakeVotingTokens: Insufficient funds send");
        if (!_banks_itmap_contains(msg.sender)) {
            TokenManager memory value;
            _banks_itmap_insert_or_update(msg.sender, value);
        }
        TokenManager storage token_manager = _banks_itmap_value_get(msg.sender);
        WrappedToken wrappedToken = WrappedToken(config.platform_token);
        uint256 total_balance = wrappedToken.balanceOf(address(this)) -
        state.total_deposit;
        TransferHelper.safeTransferFrom(config.platform_token, msg.sender,
            address(this), _amount);
        uint256 share = 0;
        if (total_balance == 0 || state.total_share == 0) {
            share = _amount;
        } else {
            share = _amount * state.total_share / total_balance;
        }

        token_manager.share += share;
        token_manager.minAmount += _amount;
        state.total_share += share;
        emit stake_voting_token(msg.sender, _amount);
    }

    function WithdrawVotingTokens(uint256 _amount) external {
        require(_banks_itmap_contains(msg.sender), "Gov WithdrawVotingTokens: Nothing staked");
        TokenManager storage token_manager = _banks_itmap_value_get(msg.sender);
        WrappedToken wrappedToken = WrappedToken(config.platform_token);
        uint256 total_balance = wrappedToken.balanceOf(address(this)) - state.total_deposit;
        uint256 locked_balance = _locked_balance(token_manager);
        uint256 locked_share = locked_balance * state.total_share / total_balance;
        uint256 withdraw_share = _amount * state.total_share / total_balance;


        require(locked_share + withdraw_share <= token_manager.share,
            "Gov WithdrawVotingTokens: User is trying to withdraw too many tokens.");
        token_manager.share -= withdraw_share;
        if (token_manager.minAmount < _amount) {
            token_manager.minAmount = 0;
        } else {
            token_manager.minAmount -= _amount;
        }
        state.total_share -= withdraw_share;
        TransferHelper.safeTransfer(config.platform_token, msg.sender, _amount);
        emit withdraw_voting_tokens(msg.sender, _amount);
    }

    function CastVote(uint256 _poll_id, uint vote, uint256 _amount) external {
        require(_poll_id > 0 && state.poll_count >= _poll_id, "Gov CastVote: Poll does not exist");
        Poll storage a_poll = _polls_itmap_value_get(_poll_id);
        require(a_poll.status == InProgress && block.number <
        a_poll.end_height, "Gov CastVote: Poll is not in progress");
        require(_banks_itmap_contains(msg.sender), "Gov CastVote: User does not have enough staked tokens.");
        TokenManager storage token_manager = _banks_itmap_value_get(msg.sender);
        require(token_manager.locked_balance[_poll_id].balance == 0, "Gov CastVote: User has already voted.");
        _update_token_manager(token_manager);
        require(token_manager.participated_polls.length < MAX_USER_VOTER_NUMBER,
            "Gov CastVote: User voted exceed MAX_USER_VOTER_NUMBER");
        WrappedToken wrappedToken = WrappedToken(config.platform_token);
        uint256 total_balance = wrappedToken.balanceOf(address(this)) - state.total_deposit;
        require(_amount * state.total_share / total_balance <= token_manager.share,
            "Gov CastVote: User does not have enough staked tokens.");
        if (vote == Yes) {
            a_poll.yes_votes += _amount;
        } else {
            a_poll.no_votes += _amount;
        }

        VoterInfo memory vote_info;
        vote_info.vote = vote;
        vote_info.balance = _amount;
        vote_info.user = msg.sender;

        token_manager.participated_polls.push(_poll_id);
        token_manager.locked_balance[_poll_id] = vote_info;
        uint256 max_poll_id = token_manager.participated_polls[token_manager.maxIdx];
        if (token_manager.locked_balance[max_poll_id].balance < _amount) {
            token_manager.maxIdx = token_manager.participated_polls.length - 1;
        }
        if (!_voters_itmap_contains(_poll_id)) {
            VoterManager memory value;
            value.user = new address[](1);
            value.vote = new uint[](1);
            value.balance = new uint256[](1);
            value.user[0] = msg.sender;
            value.vote[0] = vote;
            value.balance[0] = _amount;
            _voters_itmap_insert_or_update(_poll_id, value);
        } else {
            VoterManager storage voter_manager = _voters_itmap_value_get(_poll_id);
            voter_manager.user.push(msg.sender);
            voter_manager.vote.push(vote);
            voter_manager.balance.push(_amount);
        }
        emit cast_vote(msg.sender, _poll_id, vote, _amount);
    }

    function EndPoll(uint256 _poll_id) external {
        Poll storage _poll = polls.data[_poll_id].value;
        require (_poll.status == InProgress,"Gov EndPoll: Poll is not in progress");
        require (_poll.end_height <= block.number,"Gov EndPoll: Voting period has not expired");

        WrappedToken token = WrappedToken(config.platform_token);
        uint256 balance = token.balanceOf(address(this));
        uint256 tallied_weight = _poll.yes_votes.add(_poll.no_votes);
        uint256 staked_weight = balance.sub(state.total_deposit);
        uint256 quorum = tallied_weight.mul(10**PERCENT_PRECISION).div(staked_weight);
        bool passed = false;
        string memory rejected_reason;
        _poll.status = Rejected;
        if (tallied_weight == 0 || quorum < config.quorum){
            rejected_reason = "Quorum not reached";
        }else{
            uint256 passratio = _poll.yes_votes.mul(10**PERCENT_PRECISION).div(tallied_weight);
            if (passratio > config.threshold){
                _poll.status = Passed;
                passed = true;
            }else{
                rejected_reason = "Threshold not reached";
            }
            if (_poll.deposit_amount > 0){
                TransferHelper.safeTransfer(config.platform_token,_poll.creator,_poll.deposit_amount);
                emit to_binary(_poll.creator,_poll.deposit_amount);
            }
        }
        state.total_deposit = state.total_deposit.sub(_poll.deposit_amount);
        _poll.total_balance_at_end_poll = staked_weight;

        _voters_itmap_remove(_poll_id);
        emit end_poll_log(_poll_id,rejected_reason,passed);
    }

    function ExcutePoll(uint256 _poll_id) external {
        Poll storage _poll = polls.data[_poll_id].value;
        require(_poll.status == Passed,"Gov ExcutePoll:ExcutePoll Poll is not in passed status");
        require(_poll.end_height.add(config.effective_delay) <= block.number,"Gov ExcutePoll: ExcutePoll Effective delay has not expired");
        _passCommand(_poll.target,_poll.selector,_poll.data);
        _poll.status = Executed;
        emit execute_log(_poll_id);
    }

    function ExpirePoll(uint256 _poll_id) external {
        Poll storage _poll = polls.data[_poll_id].value;
        require(_poll.status == Passed,"Gov ExpirePoll: Poll is not in passed status");
        require((_poll.target != address(0) && bytes(_poll.selector).length > 0),"Gov ExpirePoll: Cannot make a text proposal to expired state");
        require(_poll.end_height.add(config.expiration_period) <= block.number,"Gov ExpirePoll: Expire height has not been reached");
        _poll.status = Expired;
        emit expire_log(_poll_id);
    }
    function _locked_balance(TokenManager storage _token_manager) internal returns (uint256) {
        if (_token_manager.participated_polls.length == 0) {
            return 0;
        }
        uint256 max_poll_id = _token_manager.participated_polls[_token_manager.maxIdx];
        if (polls.data[max_poll_id].value.status == InProgress) {
            return _token_manager.locked_balance[max_poll_id].balance;
        }
        _update_token_manager(_token_manager);
        if (_token_manager.participated_polls.length == 0) {
            return 0;
        }
        max_poll_id = _token_manager.participated_polls[_token_manager.maxIdx];
        return _token_manager.locked_balance[max_poll_id].balance;
    }

    function QueryConfig() external view returns (Config memory) {
        return config;
    }

    function QueryState() external view returns (State memory) {
        return state;
    }

    function QueryStaker(address user) external
        view returns (
                      voteResp[] memory lock_balance,
                      uint256 balance ,
                      uint256 share,
                      uint256 maxIdx,
                      uint256 minAmount) {
        if (!_banks_itmap_contains(user) || state.total_share == 0) {
            return (lock_balance,balance,share,maxIdx,minAmount);
        }
        WrappedToken wrappedToken = WrappedToken(config.platform_token);
        uint256 total_balance = wrappedToken.balanceOf(address(this)) - state.total_deposit;
        TokenManager storage token_manager = _banks_itmap_value_get(user);
        share = token_manager.share;
        minAmount = token_manager.minAmount;
        maxIdx = token_manager.maxIdx;
        balance = share * total_balance / state.total_share;
        lock_balance = new voteResp[](token_manager.participated_polls.length);
        for (uint256 i = 0; i < token_manager.participated_polls.length; i++) {
            uint256 poll_id = token_manager.participated_polls[i];
            lock_balance[i].value = token_manager.locked_balance[poll_id];
            lock_balance[i].poll_id = poll_id;
        }
        return (lock_balance,balance,share,maxIdx,minAmount);
    }

    function QueryPoll(uint256 _poll_id) external view returns (Poll memory poll) {
        if (_poll_id == 0 || state.poll_count < _poll_id) {
            return poll;
        }
        poll = _polls_itmap_value_get(_poll_id);
        return poll;
    }

    function QueryPolls(uint fileter, uint256 _start_after, uint256 _limit, bool _isAsc)
    external view returns (Poll[] memory poll, uint256 len) {
        if (_limit == 0) {
            return (poll , len);
        }
        uint256 limit = _limit;
        if (limit > MAX_LIMIT) {
            limit = MAX_LIMIT;
        }
        poll = new Poll[](limit);
        len = 0;
        uint256 keyindex = 1;
        if (_start_after != 0) {
            if (!_polls_itmap_contains(_start_after) ) {
                return (poll , len);
            }
            keyindex = _polls_itmap_keyindex(_start_after);
        }
        if (_isAsc) {
            if (_start_after != 0) {
                keyindex++;
            }
            if (keyindex > state.poll_count) {
                return (poll, len);
            }
            if (_polls_itmap_delete(keyindex)) {
                keyindex = _polls_itmap_iterate_next(keyindex);
            }
            for ( uint256 i = keyindex; _polls_itmap_iterate_valid(i) && (len < limit);
                i = _polls_itmap_iterate_next(i)) {
                Poll memory tmp = _polls_itmap_iterate_get(i);
                if (fileter != All && tmp.status != fileter) {
                    continue;
                }
                poll[len++] = tmp;
            }
        } else {
            if (_start_after == 0) {
                keyindex = _polls_itmap_keyindex(state.poll_count);
            } else {
                if (keyindex <= 1) {
                    return (poll, len);
                }
                keyindex--;
            }
            if (_polls_itmap_delete(keyindex)) {
                keyindex = _polls_itmap_iterate_prev(keyindex);
            }
            for (uint256 i = keyindex; _polls_itmap_iterate_valid(i) && (len < limit);
                i = _polls_itmap_iterate_prev(i)) {
                Poll memory tmp = _polls_itmap_iterate_get(i);
                if (fileter != All && tmp.status != fileter) {
                    continue;
                }
                poll[len++] = tmp;
            }
        }
    }

    function QueryVoters(uint256 poll_id, uint256 _start, uint256 _limit, bool _isAsc)
    external view returns (
        address[] memory user,
        uint256[] memory balance,
        uint[] memory opts,
        uint256) {
        uint256 len ;
        if (_limit == 0) {
            return (user,balance,opts,len);
        }
        uint256 limit = _limit;
        if (limit > MAX_LIMIT) {
            limit = MAX_LIMIT;
        }
        user = new address[](limit);
        opts = new uint[](limit);
        balance = new uint256[](limit);
        if (!_voters_itmap_contains(poll_id) ) {
            return (user,balance,opts,len);
        }
        VoterManager storage value = _voters_itmap_value_get(poll_id);
        len = 0;
        if (_start != 0) {
            if (value.user.length <= _start) {
                return (user,balance,opts,len);
            }
        }
        if (_isAsc) {
            for ( uint256 i = _start; (i < value.user.length) && (len < limit); i++) {
                user[len] = value.user[i];
                opts[len] = uint(value.vote[i]);
                balance[len] = value.balance[i];
                len++;
            }
            return (user,balance,opts,len);
        } else {
            if (_start == 0) {
                _start = value.user.length - 1;
            }
            for (int256 i = int256(_start); (i >= 0 ) && (len < limit); i--) {
                uint256 index = uint256(i);
                user[len] = value.user[index];
                opts[len] = uint(value.vote[index]);
                balance[len] = value.balance[index];
                len++;
            }
            return (user,balance,opts,len);
        }
    }
    function _update_token_manager(TokenManager storage _token_manager) internal returns (uint256) {
        _token_manager.maxIdx = 0;
        uint256 max_balance = 0;
        uint256 remove_poll_cnt = 0;
        uint256 length = _token_manager.participated_polls.length;
        for (uint256 i = 0; i < length - remove_poll_cnt; i++) {
            uint256 poll_id = _token_manager.participated_polls[i];
            while (polls.data[poll_id].value.status != InProgress) {
                remove_poll_cnt++;
                if (length - remove_poll_cnt <= i) {
                    break;
                }
                uint256 tmp = _token_manager.participated_polls[i];
                _token_manager.participated_polls[i] =
                _token_manager.participated_polls[length - remove_poll_cnt];
                _token_manager.participated_polls[length - remove_poll_cnt] = tmp;

                poll_id = _token_manager.participated_polls[i];
            }
            uint256 balance = _token_manager.locked_balance[poll_id].balance;
            if (max_balance < balance) {
                max_balance = balance;
                _token_manager.maxIdx = i;
            }
        }
        for (uint256 i = 0; i < remove_poll_cnt; i++) {
            uint256 len = _token_manager.participated_polls.length;
            uint256 poll_id = _token_manager.participated_polls[len-1];
            _token_manager.participated_polls.pop();
            delete _token_manager.locked_balance[poll_id];
        }
    }

    function _passCommand(address _target, string memory _selector, bytes memory _data) internal {
        bytes memory callData;
        if (bytes(_selector).length == 0) {
            callData = _data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(_selector))), _data);
        }
        (bool success, ) = _target.call(callData);
        require(success, "Gov Err: PassCommand transaction execution reverted.");
    }

    function _polls_itmap_insert_or_update(uint256 key, Poll memory value) internal returns (bool) {
        uint256 keyIndex = polls.data[key].keyIndex;
        polls.data[key].value = value;
        if (keyIndex > 0) return false;

        polls.keys.push(PollsKeyFlag({key: key, deleted: false}));
        polls.data[key].keyIndex = polls.keys.length;
        polls.size++;
        return true;
    }

    function _polls_itmap_contains(uint256 key) internal view returns (bool) {
        return polls.data[key].keyIndex > 0;
    }

    function _polls_itmap_keyindex(uint256 key) internal view returns (uint256) {
        return polls.data[key].keyIndex;
    }

    function _polls_itmap_delete(uint256 keyIndex) internal view returns (bool) {

        if (keyIndex == 0) {
            return true;
        }
        return polls.keys[keyIndex-1].deleted;
    }

    function _polls_itmap_iterate_valid(uint256 keyIndex) internal view returns (bool) {
        return keyIndex != 0 && keyIndex <= polls.keys.length;
    }

    function _polls_itmap_iterate_next(uint256 keyIndex) internal view returns (uint256) {
        keyIndex++;
        while (
            keyIndex < polls.keys.length && polls.keys[keyIndex-1].deleted
        ) keyIndex++;
        return keyIndex;
    }

    function _polls_itmap_iterate_prev(uint256 keyIndex) internal view returns (uint256) {
        if (keyIndex > polls.keys.length || keyIndex == 0) return polls.keys.length;

        keyIndex--;
        while (keyIndex > 0 && polls.keys[keyIndex-1].deleted) keyIndex--;
        return keyIndex;
    }

    function _polls_itmap_iterate_get(uint256 keyIndex) internal view returns
    (Poll storage value) {
        value = polls.data[polls.keys[keyIndex-1].key].value;
    }

    function _polls_itmap_value_get(uint256 key) internal view returns
    (Poll storage value) {
        uint256 keyIndex = _polls_itmap_keyindex(key);
        value = polls.data[polls.keys[keyIndex-1].key].value;
    }

    function _banks_itmap_insert_or_update(address key, TokenManager memory value) internal returns (bool) {
        uint256 keyIndex = banks.data[key].keyIndex;
        banks.data[key].value = value;
        if (keyIndex > 0) return false;

        banks.keys.push(UsersKeyFlag({key: key, deleted: false}));
        banks.data[key].keyIndex = banks.keys.length;
        banks.size++;
        return true;
    }

    function _banks_itmap_contains(address key) internal view returns (bool) {
        return banks.data[key].keyIndex > 0;
    }

    function _banks_itmap_keyindex(address key) internal view returns (uint256) {
        return banks.data[key].keyIndex;
    }

    function _banks_itmap_value_get(address key) internal view returns
    (TokenManager storage value) {
        uint256 keyIndex = _banks_itmap_keyindex(key);
        value = banks.data[banks.keys[keyIndex-1].key].value;
    }

    function _voters_itmap_insert_or_update(uint256 key, VoterManager memory value) internal returns (bool) {
        uint256 keyIndex = voters.data[key].keyIndex;
        voters.data[key].value = value;
        if (keyIndex > 0) return false;

        voters.keys.push(VotersKeyFlag({key: key, deleted: false}));
        voters.data[key].keyIndex = voters.keys.length;
        voters.size++;
        return true;
    }

    function _voters_itmap_remove(uint256 key) internal returns (bool) {
        uint256 keyIndex = voters.data[key].keyIndex;
        if (keyIndex > 0) {
            if (voters.keys[keyIndex - 1].deleted) return false;
            delete voters.data[key].value;
            voters.keys[keyIndex - 1].deleted = true;
            voters.size--;
        }
        return true;
    }

    function _voters_itmap_contains(uint256 key) internal view returns (bool) {
        return voters.data[key].keyIndex > 0;
    }

    function _voters_itmap_keyindex(uint256 key) internal view returns (uint256) {
        return voters.data[key].keyIndex;
    }

    function _voters_itmap_value_get(uint256 key) internal view returns
    (VoterManager storage value) {
        uint256 keyIndex = _voters_itmap_keyindex(key);
        value = voters.data[voters.keys[keyIndex-1].key].value;
    }
}
