// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "./LibAddressSet.sol";
import "./LibArray.sol";
import "../nft/nft.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../ItokenId/ItokenId.sol";
contract Handing is IERC721Receiver {
    using LibAddressSet for LibAddressSet.AddressSet;
    event received_log(address,uint256,uint256);
    event reset_number(uint256,uint256,uint256,uint256,uint256,uint256);
    event record_mix(address user,uint256[] _mix_card,uint256 _grade,uint256 _series_id);
    event record_draw(address user,uint256 number,uint256 _series_id);
    event cycle_card_log(uint256,uint256);
    mapping(address => bool) private recorder;

    uint256 public MAX_DRAW = 1000;
    uint256 public MAX_RECORD = 10;
    uint256 public MAX_AWARD_PLAYER = 10;
    uint256 public RECORD_NUMBER = 2000;
    uint256 public MAX_TIME = 24*60*60;
    uint256 public MAX_RECEIVE = 20;
    uint256 public MAX_RECEIVE_QUERY = 20;
    uint256 public CYCLE = 1;
    bool private once = true;
    address nft_address;
    address iTokenId;

    function init(address _nft,address _owner,address _tokenId)external{
        require (once,"Err:only be modified once");
        nft_address = _nft;
        iTokenId = _tokenId;
        recorder[_nft] = true;
        recorder[_owner] = true;
        once = false;
    }

    function reset_recorder(address _recorder,bool _button) onlyRecorder external{
        recorder[_recorder] = _button;
    }

    constructor()public{
        draw.last_time = now;
    }

    struct RewardList {
        uint256 box;
        uint256 lock;
        uint256[][] mix;
        uint256[] mix_grade_ids;
    }

    struct PlayerReward{
        uint256[] cardList;
    }

    struct DrawTree{
        uint256 last_time;
        uint256 draw_count;
    }
    DrawTree private draw;

    struct Card{
        uint256 types;
        uint256 random_number;
        uint256 seriesId;
        address user;
        uint256[] mix_card;
        uint256 grade;
        uint256 tokenId;
        uint256 cycle;
    }
    mapping(uint256 => Card) public cardList;
    uint256[] public cardList_arr;

    mapping(address => mapping(uint256 => RewardList)) private wait_fill;
    mapping(address => uint256[]) private user_series;
    LibAddressSet.AddressSet private wait_user;
    mapping(address => PlayerReward) private wait_receive;

    function record(address _user,
                    uint256 _box,
                    uint256[] calldata _mix,
                    uint256 _mix_grade_id,
                    uint256 _series_id)onlyRecorder external{

        if (!wait_user.contains(_user)){
            wait_user.add(_user);
        }
        RewardList storage _reward_list = wait_fill[_user][_series_id];
        if (_box > 0){
            _reward_list.box += _box;
            emit record_draw(_user,_box,_series_id);
        }
        uint256 mix_num = 0;
        if (_mix_grade_id > 0 && _mix.length > 0){
            LibArray.addValue(_reward_list.mix,_mix);
            _reward_list.mix_grade_ids.push(_mix_grade_id);
            mix_num = 1;
            emit record_mix(_user,_mix,_mix_grade_id,_series_id);
        }
        _addValue(user_series[_user],_series_id);
        draw.draw_count += (_box + mix_num);
        require (draw.draw_count < RECORD_NUMBER,
                 "Handing Err: draw count reach the upper limit");
    }

    //send reward
    function award(uint256 types)external returns(bool) {
        if (types == 888){
            require(recorder[msg.sender],"HandingOut Err:No access");
        }else{
            require((draw.draw_count >= MAX_DRAW) ||
                    ((now - draw.last_time) >= MAX_TIME),
                    "HandingOut Err:conditions were not met");
        }
        uint256 counter = 0;
        uint256 player = 0;
        uint256 rand = ItokenId(iTokenId).getRandomNumber(msg.data, msg.sender);
        for (uint i = 0; i < wait_user.getSize();){
            address user = wait_user.get(i);
            uint256[] storage _series_ids = user_series[user];
            for (uint j = 0 ; j < _series_ids.length;){
                RewardList storage _reward_list = wait_fill[user][_series_ids[j]];
                if (_reward_list.box > 0){
                    uint256 _boxNum = _reward_list.box;
                    bool button = false;
                    if (_boxNum + counter > MAX_RECORD){
                        _boxNum = MAX_RECORD - counter;
                        button = true;
                    }
                    award_box(_boxNum,_series_ids[j],user,rand);
                    _reward_list.box = _reward_list.box - _boxNum;
                    counter += _boxNum;
                    if (counter >= MAX_RECORD && button){
                        return false;
                    }
                }
                for (uint k = 0; k < _reward_list.mix.length;){
                    award_mix(_reward_list.mix[k],user,_series_ids[j],_reward_list.mix_grade_ids[k],
                              uint256(keccak256(abi.encodePacked(rand,k))));
                    LibArray.removeByIndex(_reward_list.mix,k);
                    removeByIndex(_reward_list.mix_grade_ids,k);
                    counter += 1;
                    if (counter >= MAX_RECORD){
                        return false;
                    }
                }
                delete wait_fill[user][_series_ids[j]];
                removeByIndex(_series_ids,j);
                if (user_series[user].length == 0){
                    wait_user.remove(user);
                }
            }
            player += 1;
            if (player > MAX_AWARD_PLAYER){
                return false;
            }
        }
        emit cycle_card_log(CYCLE,now);
        draw.last_time = now;
        draw.draw_count = 0;
        CYCLE++;
        return true;
    }

    function removeByIndex(uint256[] storage array, uint index) internal{
    	require(index < array.length, "Handing Err: index out of bounds");
        while (index < array.length - 1) {
            array[index] = array[index + 1];
            index++;
        }
        array.pop();
    }

    function award_mix(uint256[] memory _mix,address _user,uint256 _series_id,uint256 _grade,uint256 rand)internal{
        uint256 tokenId = nft(nft_address).DrawPro();
        wait_receive[_user].cardList.push(tokenId);
        cardList[tokenId].random_number = uint256(keccak256(abi.encodePacked(rand,_user,_series_id,_grade)));
        cardList[tokenId].user = _user;
        cardList[tokenId].grade = _grade;
        cardList[tokenId].mix_card = _mix;
        cardList[tokenId].types = 2;
        cardList[tokenId].seriesId = _series_id;
        cardList[tokenId].tokenId = tokenId;
        cardList[tokenId].cycle = CYCLE;
        cardList_arr.push(tokenId);
    }

    function award_box(uint256 _box,uint256 _series_id,address _user,uint256 rand)internal{
        uint256[] memory _token_ids = nft(nft_address).DrawPros(_box);
        for(uint i = 0; i < _token_ids.length; i++){
            wait_receive[_user].cardList.push(_token_ids[i]);
            cardList[_token_ids[i]].random_number =
                uint256(keccak256(abi.encodePacked(rand,_box,_series_id,_user,_token_ids[i])));
            cardList[_token_ids[i]].seriesId = _series_id;
            cardList[_token_ids[i]].user = _user;
            cardList[_token_ids[i]].types = 1;
            cardList[_token_ids[i]].tokenId = _token_ids[i];
            cardList[_token_ids[i]].cycle = CYCLE;
            cardList_arr.push(_token_ids[i]);
        }
    }

    //receive award
    function received() external {
        require ( wait_receive[msg.sender].cardList.length > 0,"Handing Err:no reward");
        uint256 tokenLens = wait_receive[msg.sender].cardList.length;
        uint256  lens = tokenLens>MAX_RECEIVE?MAX_RECEIVE:tokenLens;
        for (uint j = 0;j < lens;){
            uint256 tokenId = wait_receive[msg.sender].cardList[wait_receive[msg.sender].cardList.length - 1];
            Card memory card_list = cardList[tokenId];
            if (card_list.types == 1){
                nft(nft_address).MintPro(msg.sender,card_list.seriesId,card_list.random_number,tokenId);
            }else if (card_list.types == 2){
                nft(nft_address).MintMixPro(msg.sender,
                                            card_list.seriesId,card_list.grade,card_list.random_number,tokenId);
            }
            wait_receive[msg.sender].cardList.pop();
            emit received_log(msg.sender,tokenId,card_list.types);
            if (lens >= 1){
                lens--;
            }
        }
    }

    //query the number of user reward cards
    function queryCardListLens(address _user) external view returns (uint256){
        return (wait_receive[_user].cardList.length);
    }

    //query reward view the number of unclaimed cards
    function queryReward(address _user)external view returns (uint256,bool){
        bool yorn = wait_receive[_user].cardList.length > 0 ? true:false;
        return (wait_receive[_user].cardList.length,yorn);
    }

    //queryNowReward returns the current number of times and the next time
    //can rewards be issued
    function queryNowReward()external view returns (uint256,uint256,bool){
        uint256 wait = now < draw.last_time + MAX_TIME ? draw.last_time + MAX_TIME - now : 0;
        bool yorn = wait == 0  ? true : false;
        if (!yorn) {
            yorn = draw.draw_count >= MAX_DRAW ? true : false;
        }
        return (draw.draw_count,wait,yorn);
    }

    // query waiting for the number of users
    function queryWaitUserSize()external view returns (uint256){
        return wait_user.getSize();
    }

    // query users to receive 20, and total numbers
    function queryUserRecieved(address _user)external view returns (uint256[] memory,uint256){
        uint256 tokenLens = wait_receive[_user].cardList.length;
        uint256  lens = tokenLens > MAX_RECEIVE_QUERY ? MAX_RECEIVE_QUERY:tokenLens;
        uint256[] memory tokenList = new uint256[](lens);
        for (uint j = 0;j < lens;j++){
            tokenList[j] = wait_receive[_user].cardList[tokenLens - 1 - j];
        }
        return (tokenList,tokenLens);
    }

    function queryWaitFill(address _user,uint256 _series_id)external view returns (uint256,uint256){
        RewardList storage _reward_list = wait_fill[_user][_series_id];
        return(_reward_list.box,_reward_list.mix.length);
    }

    function queryCardListByValue(uint256 _tokenId,uint256 lens) external view returns (Card[] memory result){
        if(_tokenId < cardList_arr[0]){
            return result;
        }
        (bool iN,uint index) = _binarySearch(cardList_arr,_tokenId);
        if (!iN){
            return result;
        }
        lens = lens > 20 ? 20:lens;
        if (index + lens >= cardList_arr.length){
            lens = cardList_arr.length - 1 - index;
        }
        Card[] memory result = new Card[](lens+1);
        uint temp;
        for (uint i = index; i < index+lens + 1; i++){
            result[temp] = cardList[cardList_arr[i]];
            temp++;
        }
        return result;
    }

    function resetNumber(uint256 max_draw,
                         uint256 max_time,
                         uint256 max_receive,
                         uint256 max_player,
                         uint256 max_record,
                         uint256 max_record_number) onlyRecorder public{
        MAX_RECEIVE = max_receive;
        MAX_TIME = max_time;
        MAX_DRAW = max_draw;
        MAX_RECORD = max_record;
        MAX_AWARD_PLAYER = max_player;
        RECORD_NUMBER = max_record_number;
        emit reset_number(max_draw,max_time,max_receive,max_player,max_record,max_record_number);
    }

    function _addValue(uint256[] storage array, uint256 value) internal{
    	uint index;
        bool isIn;
        (isIn, index) = _firstIndexOf(array, value);
        if(!isIn){
        	array.push(value);
        }
    }

    function _firstIndexOf(uint256[] storage array, uint256 key) internal view returns (bool, uint256) {
    	if(array.length == 0){
    		return (false, 0);
    	}
    	for(uint256 i = 0; i < array.length; i++){
    		if(array[i] == key){
    			return (true, i);
    		}
    	}
    	return (false, 0);
    }

    function _binarySearch(uint256[] storage array, uint256 key) internal view returns (bool, uint) {
        if(array.length == 0){
        	return (false, 0);
        }

        uint256 low = 0;
        uint256 high = array.length-1;

        while(low <= high){
        	uint256 mid = _average(low, high);
        	if(array[mid] == key){
        		return (true, mid);
        	}else if (array[mid] > key) {
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        return (false, 0);
    }

    function _average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }

    function onERC721Received(address, address, uint256, bytes memory) public
        virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier onlyRecorder(){
        require(recorder[msg.sender],"HandingOut Err:no right to keep accounts");
        _;
    }

}
