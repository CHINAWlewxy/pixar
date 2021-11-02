// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../TransferHelper.sol";
import "./BuildToken.sol";
import "../token/TokenControllerInterface.sol";
import "../token/ControlledToken.sol";
import "../token/WrappedToken.sol";
import "../prizePool/PrizePool.sol";
import "../nft/nft.sol";
import "../ItokenId/ItokenId.sol";

contract BlindBox is ERC20PermitUpgradeable {
    using SafeMath for uint256;
    event mint_box(uint256, string);
    event draw_out(address, uint256, uint256);
    event draw(address, uint256,address,uint256);
    event mix_true(address, uint256, uint256, bool);
    event resetDraw(uint256 ,uint256[]);
    event resetMix(uint256 _series_id, uint256[]);
    event resetReward(uint256 _series_id, Reward);
    event resetLevel(uint256,uint256[]);
    event reset_ratio(uint256);
    event resetOwner(address);
    event add_box_pro(address);
    uint256 public constant MIN_NAME_LENGTH = 4;
    uint256 public constant MIN_IMAGE_LINK_LENGTH = 8;
    uint256 public constant MAX_IMAGE_LINK_LENGTH = 128;
    uint256 public constant MIX_TRUE_LOW_LEVEL_NUMBER = 5;
    uint256 public constant DEFAUL_DECIMAL_PLACES = 100;
    uint256 public DrawNumber = 3;
    uint256 ratio = 1000;

    struct Config {
        address owner;
        address lable_address;
        address platform_token;
        address key_token;
        address payable prize_pool;
        address flip;
        address nft;
        address iTokenId;
        address box_pro;
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

    BuildToken public controlledTokenBuilder;

    mapping(uint256 => Box) public box_info;

    uint256[] series_ids;

    constructor(address _owner,
                address _lableAddress,
                address platform_token,
                BuildToken _controlledTokenBuilder,
                address _nft,
                address _itokenid) public {
        controlledTokenBuilder = _controlledTokenBuilder;
        config = Config(_owner, _lableAddress,platform_token,address(0),address(0),address(0),_nft,_itokenid,
                        address(0));
    }

    function init(BuildToken.ControlledTokenConfig calldata _config,address _flip,address  _prize_pool)onlyOwner external {
        require(_flip != address(0) &&
                config.flip == address(0) &&
                config.key_token == address(0),
                "BlindBox Err:Can not be re-initialized");
        ControlledToken token = _createToken(_config.name, _config.symbol, _config.decimals, _config.controller);
        config.key_token = address(token);
        config.flip = _flip;
        config.prize_pool = payable(_prize_pool);
    }

    function addBoxPro(address _box_pro,address handing) onlyOwner external {
        config.box_pro = _box_pro;
        nft(config.nft).addBoxPro(payable(_box_pro),handing);
        PrizePool(config.prize_pool).addBoxPro(_box_pro);
        emit add_box_pro(_box_pro);
    }

    function MintBox(Box memory _box)
        onlyOwner
        checkBox(_box) public {
        uint256 gap = 5 - _box.level.length;
        if(gap > 0){
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

    //ptoken - > k token ratio default 2 decimal places
    function Draw(uint256 _number, address _inviter)
        onlynumberofDraw(_number) external
    {
        //keytoken(_number) * ratio = ptoken
        uint256 drawNumber = _number * 10 ** 18 / DEFAUL_DECIMAL_PLACES * ratio;
        require(_inviter != address(0), "BlindBox Err:inviter cannot equal address(0)");
        WrappedToken platform_token = WrappedToken(config.platform_token);
        uint256 amount = platform_token.allowance(msg.sender, address(this));
        require(amount >= drawNumber , "BlindBox Err:amount cannot than allowance");
        TransferHelper.safeTransferFrom(config.platform_token, msg.sender, address(this), drawNumber);
        //platform_token.burn(drawNumber/10, msg.sender);
        TransferHelper.safeTransfer(config.platform_token, config.prize_pool, drawNumber / 10 * 9);
        TransferHelper.safeTransfer(config.platform_token, config.lable_address, drawNumber / 100 * 5);
        TransferHelper.safeTransfer(config.platform_token, _inviter, drawNumber / 100 * 5);
        _mint(msg.sender, _number*10**18, _number);
        emit draw(msg.sender, _number,_inviter,drawNumber);
    }

    function ResetRatio(uint256 _ratio) onlyOwner external {
        ratio = _ratio;
        emit reset_ratio(_ratio);
    }

    function mintKey(address sender,uint256 number) onlyFlip external{
        if (number == 1){
            _mint(sender, 1*10**18, 1);
        }else{
            _mint(sender, 10*10**18, 1);
        }
    }
    function burnKey(address user,uint256 number) onlyBoxPro external{
        ControlledToken(config.key_token).controllerBurn(user,number);
    }

    function DrawOut(uint256 _series_id, uint256 _number)
        onlyBox(_series_id)
        onlynumberofDrawOut(_number) external
    {
        require(msg.sender == tx.origin,"BlindBox Err:request failed");
        WrappedToken key_token = WrappedToken(config.key_token);
        uint256 amount = key_token.allowance(msg.sender, address(this));
        require(amount >= _number * 10 ** 18, "BlindBox Err:amount cannot than allowance");
        nft(config.nft).Draw(msg.sender,_number,1,_series_id,ItokenId(config.iTokenId).getRandomNumber(msg.data, msg.sender));
        ControlledToken(config.key_token).controllerBurn(msg.sender,_number * 10 ** 18);
        emit draw_out(msg.sender, _series_id, _number);
    }

    function MixTrue(uint256 _series_id, uint256 _grade_id,uint256[] calldata _tokens_id)
        onlyBox(_series_id)
        onlyGrade(_grade_id)
        checkTokenIdLens(_tokens_id)
        external {
        require(msg.sender == tx.origin,"BlindBox Err:request failed");
        nft(config.nft).gradeCompose(msg.sender,_series_id,_grade_id,_tokens_id,ItokenId(config.iTokenId).getRandomNumber(msg.data, msg.sender));
    }

    function Convert(uint256 _series_id,uint256[] calldata _token_ids)
        onlyBox(_series_id) external {
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

    function ResetOwner(address _owner) onlyOwner external{
        config.owner = _owner;
        emit resetOwner(_owner);
    }

    function ResetDraw(uint256 _series_id, uint256[] calldata _draw)
        onlyOwner
        onlyBox(_series_id) external {
        require (_draw.length == 4,"Blindbox Err:reset err");
        uint256 levelLens = than(box_info[_series_id].level);
        uint256 drawLens = than(_draw);
        if (levelLens == 5){
            require (drawLens == levelLens - 1,"Blindbox Err:draw err");
        }else{
            require (drawLens == levelLens ,"Blindbox Err:draw err");
        }
        uint256 drawed;
        for(uint i = 0; i < _draw.length; i++){
            drawed += _draw[i];
        }
        require(drawed == 1000000,"BlindBox Err:request err");
        box_info[_series_id].draw = _draw;
        emit resetDraw(_series_id, _draw);
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

    function ResetMix(uint256 _series_id, uint256[] calldata _mix)
        onlyOwner
        onlyBox(_series_id) external {
        require (_mix.length == 4,"Blindbox Err: reset err");
        uint256 levelLens = than(box_info[_series_id].level);
        require (_mix.length == levelLens - 1,"Blindbox Err:reset err");
        box_info[_series_id].mix = _mix;
        for(uint i = 0; i < _mix.length; i++){
            require(_mix[i] <=  1000000,"BlindBox Err: request err");
        }
        emit resetMix(_series_id, _mix);
    }

    function ResetReward(uint256 _series_id, Reward memory _reward)
        onlyOwner
        onlyBox(_series_id) public {
        require(_reward.token.length == _reward.amount.length,
                "BlindBox Err: reward token not equal reward amount");
        box_info[_series_id].reward = _reward;
        emit resetReward(_series_id, _reward);
    }

    function ResetDrawNumber(uint256 _drawNumber)
        onlyOwner external{
        DrawNumber = _drawNumber;
    }

    function QueryBox(uint256 _series_id) external view returns (Box memory){
        return box_info[_series_id];
    }

    function QueryConfig() external view returns (Config memory){
        return config;
    }

    function QuerySeriesIds() external view returns (uint256[] memory){
        return series_ids;
    }

    function QuerySeriesIdsNotNull() public view returns (uint256[] memory,uint256){
        uint256 len = 0;
        uint256[] memory seriesIds = new uint256[](series_ids.length);
        for(uint i = 0; i < series_ids.length; i++){
            uint256[] memory levels = QueryLevels(series_ids[i]);
            if (levels[4]>0){
                seriesIds[len] = series_ids[i];
                len++;
            }
        }
        return (seriesIds,len);
    }

    function QueryRatio() view external returns (uint256 ,uint256){
        return (1*10**18/DEFAUL_DECIMAL_PLACES*ratio
                ,10*10**18/DEFAUL_DECIMAL_PLACES*ratio);
    }

    function QueryDraws(uint256 _series_id) external view returns (uint256[] memory){
        return box_info[_series_id].draw;
    }

    function QueryLevels(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].level;
    }

    function QueryImage(uint256 _series_id) external view returns (string memory){
        return box_info[_series_id].image;
    }

    function QueryMix(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].mix;
    }
    function QueryBoxs(
                       uint256 start,
                       uint256 end
                       ) external view returns (Box[] memory, uint256){
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

    function _mint(address to, uint256 amount, uint256 number) internal {
        ControlledToken(config.key_token).controllerMint(to, amount, number);
    }

    function _createToken(
        string memory name,
        string memory token,
        uint8 decimals,
        TokenControllerInterface controller
    ) internal returns (ControlledToken){
        return controlledTokenBuilder.createControlledToken(
            BuildToken.ControlledTokenConfig(name, token, decimals, controller));
    }

    modifier onlyOwner(){
        require(msg.sender == config.owner, "BlindBox Err: Unauthoruzed");
        _;
    }

    modifier onlyFlip(){
        require(msg.sender == config.flip, "BlindBox Err: Unauthoruzed");
        _;
    }
    modifier onlyBoxPro(){
        require(msg.sender == config.box_pro, "BlindBox Err: Unauthoruzed");
        _;
    }

    modifier onlynumberofDraw(uint256 _number){
        require(_number == 1 || _number == 10, "BlindBox Err:draw number can only be equal to 1 or 10");
        _;
    }

    modifier onlynumberofDrawOut(uint256 _number){
        require(_number == 1 || _number == DrawNumber, "BlindBox Err:Only draw the specified number");
        _;
    }

    modifier checkBox(Box memory _box){
        uint256 nameLen = bytes(_box.name).length;
        require(nameLen >= MIN_NAME_LENGTH, "BlindBox Err: name length must be less than MIN_NAME_NAME");
        Box storage _box_info = box_info[_box.series_id];
        require(_box_info.series_id == 0, "BlindBox Err: Box already exists");
        uint256 imageLinkLen = bytes(_box.image).length;
        require(imageLinkLen >= MIN_IMAGE_LINK_LENGTH,
                "BlindBox Err: ImageLink length must be less than MIN_IMAGE_LINK_LENGTH");
        require(imageLinkLen <= MAX_IMAGE_LINK_LENGTH,
                "BlindBox Err: ImageLink length must be small than MAX_IMAGE_LINK_LENGTH");
        require(_box.reward.token.length == _box.reward.amount.length,
                "BlindBox Err: reward token not equal reward amount");

        for(uint i = 0; i < _box.level.length; i++){
            require(_box.level[i]>0,"BlindBox Err: request err");
        }
        uint256 drawed;
        for(uint i = 0; i < _box.draw.length; i++){
            require(_box.draw[i]>0,"BlindBox Err: request err");
            drawed += _box.draw[i];
        }
        require(drawed == 1000000,"BlindBox Err:request err");
        require(_box.level.length >= 2 && _box.level.length <= 5,"BlindBox Err:request err");
        if(_box.level.length ==5){
            require(_box.draw.length == 4 && _box.mix.length == 4,"BlindBox Err: Request err");
        }else{
            require(_box.draw.length == _box.level.length && _box.mix.length == _box.level.length - 1,
                    "BlindBox Err: Request err");
        }
        _;

    }

    modifier onlyGrade(uint256 _grade_id){
        require(_grade_id <= 5,"BlindBox  Err:Grade does not exist");
        _;
    }

    modifier checkTokenIdLens(uint256[] memory _tokens_id){
        require(_tokens_id.length ==  MIX_TRUE_LOW_LEVEL_NUMBER,"BlindBox Err: Only receive 5 nft token id");
        _;
    }

    modifier onlyBox(uint256 _series_id){
        Box storage _box_info = box_info[_series_id];
        require(_box_info.series_id != 0, "BlindBox Err: series not found");
        _;
    }
}
