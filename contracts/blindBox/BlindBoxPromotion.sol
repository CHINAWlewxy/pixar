// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../TransferHelper.sol";
import "./BuildToken.sol";
import "./BlindBox.sol";
import "../token/TokenControllerInterface.sol";
import "../token/ControlledToken.sol";
import "../token/WrappedToken.sol";
import "../prizePool/PrizePool.sol";
import "../nft/nft.sol";
import "../handing/handing.sol";
import "@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol";

contract BlindBoxPromotion is ERC20PermitUpgradeable {
    using SafeMath for uint256;
    event mint_box(uint256, string);
    event draw_out(address, uint256, uint256);
    event mix_true(address, uint256, uint256, bool);
    event resetDraw(uint256 ,uint256[]);
    event resetMix(uint256 _series_id, uint256[]);
    event resetReward(uint256 _series_id, Reward);
    event resetLevel(uint256,uint256[]);

    uint256 public constant MIN_NAME_LENGTH = 4;
    uint256 public constant MIN_IMAGE_LINK_LENGTH = 8;
    uint256 public constant MAX_IMAGE_LINK_LENGTH = 128;
    uint256 public constant MIX_TRUE_LOW_LEVEL_NUMBER = 5;
    uint256 public constant DEFAUL_DECIMAL_PLACES = 100;
    uint256 public DrawNumber = 10;
    struct Config {
        address owner;
        address payable boxV1;
        address lable_address;
        address platform_token;
        address key_token;
        address payable prize_pool;
        address nft;
        address handing;
    }

    Config public config;

    struct Box {
        string  name;
        uint256 series_id;
        string  image;
        uint256[] level;
        uint256[] draw;
        uint256[] mix;
        Reward reward;
    }

    struct Reward {
        address[] token;
        uint256[] amount;
    }

    mapping(uint256 => Box) public box_info;
    uint256[] series_ids;
    constructor() public {
        config.owner = msg.sender;
    }
    function initPromotion(address _owner,
                           address _boxV1,
                           address _lableAddress,
                           address _key,
                           address _prize_pool,
                           address _nft,
                           address _handing,
                           address _platform_token,
                           address _tokenId) onlyOwner external{
        config = Config(_owner,payable(_boxV1),_lableAddress,_platform_token,_key,payable(_prize_pool),_nft,_handing);
        Handing(config.handing).init(_nft,_owner,_tokenId);
    }

    function MintBox(Box memory _box)
        onlyOwner
        checkBox(_box) public {
        uint256 gap = 5 - _box.level.length;
        if (gap > 0){
            uint256[] memory level = new uint256[](5);
            uint256[] memory drawed = new uint256[](4);
            uint256[] memory mix = new uint256[](4);
            for(uint i = 0; i < _box.level.length; i++){
                level[i] = _box.level[i];
            }
            for(uint i = 0; i < _box.draw.length; i++){
                drawed[i] = _box.draw[i];
            }
            for(uint i = 0; i < _box.mix.length; i++){
                mix[i] = _box.mix[i];
            }
            _box.mix = mix;
            _box.draw = drawed;
            _box.level = level;
        }
        box_info[_box.series_id] = _box;
        series_ids.push(_box.series_id);
        emit mint_box(_box.series_id, _box.name);
    }

    function DrawOut(uint256 _series_id, uint256 _number)
        onlyBox(_series_id)
        onlynumberofDrawOut(_number) public
    {
        require(msg.sender == tx.origin,"BlindBoxPromotion Err:request failed");
        WrappedToken key_token = WrappedToken(config.key_token);
        uint256 amount = key_token.allowance(msg.sender, address(this));
        require(amount >= _number * 10 ** 18, "BlindBoxPromotion Err:amount cannot than allowance");
        uint256[] memory _mix;
        Handing(config.handing).record(msg.sender,_number,_mix,0,_series_id);
        BlindBox(config.boxV1).burnKey(msg.sender,_number*10**18);
        emit draw_out(msg.sender, _series_id, _number);
    }

    function MixTrue(uint256 _series_id, uint256 _grade_id,uint256[] memory _tokens_id)
        onlyBox(_series_id)
        onlyGrade(_grade_id)
        checkTokenIdLens(_series_id,_tokens_id)
        public {
        require(msg.sender == tx.origin,"BlindBoxPromotion Err:request failed");
        require(_tokens_id.length == 5,"BlindBoxPromotion Err:tokenids failed");
        nft(config.nft).checkMix(msg.sender,_series_id,_grade_id,_tokens_id);
        Handing(config.handing).record(msg.sender,0,_tokens_id,_grade_id,_series_id);
    }

    function Convert(uint256 _series_id,uint256[] memory _token_ids)
        onlyBox(_series_id) public {
        nft(config.nft).cashCheckByTokenID(msg.sender,_series_id,box_info[_series_id].level,_token_ids);
        _sendReward(_series_id);
    }

    receive() external payable{}

    function _sendReward(uint256 _series_id) internal {
        Box storage _box = box_info[_series_id];
        uint256 reward_lens = _box.reward.token.length;
        for (uint i = 0; i < reward_lens; i++) {
            address token = _box.reward.token[i];
            uint256 amount = _box.reward.amount[i];
            PrizePool(config.prize_pool).sender(msg.sender,token, amount);
        }
    }

    event resetOwner(address);
    function ResetOwner(address _owner) onlyOwner public{
        config.owner = _owner;
        emit resetOwner(_owner);
    }

    function ResetDraw(uint256 _series_id, uint256[] memory _draw)
        onlyOwner
        onlyBox(_series_id) public {
        require (_draw.length == 4,"BlindBoxPromotion Err:reset err");
        uint256 levelLens = than(box_info[_series_id].level);
        uint256 drawLens = than(_draw);
        require (drawLens == levelLens,"BlindBoxPromotion Err:draw err");
        box_info[_series_id].draw = _draw;
        uint256 drawed;
        for(uint i = 0; i < _draw.length; i++){
            drawed += _draw[i];
        }
        require(drawed == 1000000,"BlindBoxPromotion Err:request err");
        emit resetDraw(_series_id, _draw);
    }

    function ResetMix(uint256 _series_id, uint256[] memory _mix)
        onlyOwner
        onlyBox(_series_id) public {
        require (_mix.length == 3,"BlindBoxPromotion Err: reset err");
        uint256 levelLens = than(box_info[_series_id].level);
        require (_mix.length == levelLens - 1,"BlindBoxPromotion Err:reset err");
        box_info[_series_id].mix = _mix;
        for(uint i = 0; i < _mix.length; i++){
            require(_mix[i] <=  1000000,"BlindBoxPromotion Err: request err");
        }
        emit resetMix(_series_id, _mix);
    }

    function than(uint256[] memory _arr)internal pure returns(uint256){
        uint256 temp = 0;
        for (uint i = 0; i < _arr.length; i++){
            if (_arr[i] > 0 ){
                temp++;
            }
        }
        return temp;
    }

    function ResetReward(uint256 _series_id, Reward memory _reward)
        onlyOwner
        onlyBox(_series_id)public {
        require(_reward.token.length == _reward.amount.length,
                "BlindBoxPromotion Err: reward token not equal reward amount");
        box_info[_series_id].reward = _reward;
        emit resetReward(_series_id, _reward);
    }

    function ResetDrawNumber(uint256 _drawNumber)
        onlyOwner public{
        DrawNumber = _drawNumber;
    }

    function QueryBox(uint256 _series_id) public view returns (Box memory){
        return box_info[_series_id];
    }

    function QueryConfig() public view returns (Config memory){
        return config;
    }

    function QuerySeriesIds() public view returns (uint256[] memory){
        return series_ids;
    }

    function QuerySeriesIdsNotNull() public view returns (uint256[] memory,uint256){
        uint256 len;
        uint256[] memory seriesIds = new uint256[](series_ids.length);
        for(uint i = 0; i < series_ids.length; i++){
            uint256[] memory levels = QueryLevels(series_ids[i]);
            if (levels[series_ids.length -1]>0){
                seriesIds[i] = series_ids[i];
                len++;
            }
        }
        return (seriesIds,len);
    }

    function QueryDraws(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].draw;
    }

    function QueryMix(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].mix;
    }


    function QueryLevels(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].level;
    }

    function QueryImage(uint256 _series_id) public view returns (string memory){
        return box_info[_series_id].image;
    }

    function QueryBoxs(
                       uint256 start,
                       uint256 end
                       ) public view returns (Box[] memory, uint256){


        uint256 lens = series_ids.length;
        if (lens <= 0 || start > end || start > lens){
            Box[] memory result;
            return (result, lens);
        }
        uint256 index = end;
        if (end > lens) {
            index = lens;
        }
        if (index - start > 30){
            index = start + 30;
        }
        Box[] memory result = new Box[](index - start);
        uint id;
        for (uint i = start; i < index; i++) {
            result[id] = box_info[series_ids[i]];
            id++;
        }
        return (result, lens);
    }

    modifier onlyOwner(){
        require(msg.sender == config.owner, "BlindBoxPromotion Err: Unauthoruzed");
        _;
    }

    modifier onlynumberofDraw(uint256 _number){
        require(_number == 1 || _number == 10, "BlindBoxPromotion Err:draw number can only be equal to 1 or 10");
        _;
    }

    modifier onlynumberofDrawOut(uint256 _number){
        require(_number == 1 || _number == DrawNumber, "BlindBoxPromotion Err:Only draw the specified number");
        _;
    }

    modifier checkBox(Box memory _box){
        uint256 nameLen = bytes(_box.name).length;
        require(nameLen >= MIN_NAME_LENGTH, "BlindBoxPromotion Err: name length must be less than MIN_NAME_NAME");
        Box storage _box_info = box_info[_box.series_id];
        require(_box_info.series_id == 0, "BlindBoxPromotion Err: Box already exists");
        uint256 imageLinkLen = bytes(_box.image).length;
        require(imageLinkLen >= MIN_IMAGE_LINK_LENGTH,
                "BlindBoxPromotion Err: ImageLink length must be less than MIN_IMAGE_LINK_LENGTH");
        require(imageLinkLen <= MAX_IMAGE_LINK_LENGTH,
                "BlindBoxPromotion Err: ImageLink length must be small than MAX_IMAGE_LINK_LENGTH");
        require(_box.reward.token.length == _box.reward.amount.length,
                "BlindBoxPromotion Err: reward token not equal reward amount");
        for(uint i = 0; i < _box.level.length; i++){
            require(_box.level[i]>0,"BlindBoxPromotion Err: request err");
        }
        uint256 drawed;
        for(uint i = 0; i < _box.draw.length; i++){
            require(_box.draw[i]>0,"BlindBoxPromotion Err: request err");
            drawed += _box.draw[i];
        }
        require(drawed == 1000000,"BlindBoxPromotion Err:request err");
        require(_box.level.length >= 2 && _box.level.length <= 4,"BlindBoxPromotion Err:request err");
        require(_box.draw.length == _box.level.length && _box.mix.length == _box.level.length - 1,
                "BlindBoxPromotion Err: Request err");
        _;
    }

    modifier onlyGrade(uint256 _grade_id){
        require(_grade_id >1 && _grade_id <= 4,"BlindBoxPromotion  Err:Grade does not exist");
        _;
    }

    modifier checkTokenIdLens(uint256 _series_id,uint256[] memory _tokens_id){
        require(_tokens_id.length ==  MIX_TRUE_LOW_LEVEL_NUMBER,"BlindBoxPromotion Err: Only receive 5 nft token id");
        _;
    }

    modifier onlyBox(uint256 _series_id){
        Box storage _box_info = box_info[_series_id];
        require(_box_info.series_id != 0, "BlindBoxPromotion Err: series not found");
        _;
    }
}
