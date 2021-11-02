pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "../token/WrappedToken.sol";
import "../TransferHelper.sol";
contract Community{

    struct Config{
        address owner;
        address platform_token;
        uint256 spend_limit;
    }
    Config public config;
    constructor(
                address _owner,
                address _platform_token,
                uint256 _spend_limit
    )public{
        config.owner = _owner;
        config.platform_token = _platform_token;
        config.spend_limit = _spend_limit;
    }
    event update_config_log(address,uint256);
    event spend_log(address,uint256);
    function UpdateConfig(address _owner,uint256 _spend_limit)external{
        require(msg.sender == config.owner,"Community: UpdateConfig Unauthoruzed");
        config.owner = _owner;
        config.spend_limit = _spend_limit;
        emit update_config_log(_owner,_spend_limit);
    }

    function Spend(address _recipient,uint256 _amount)public{
        require(msg.sender == config.owner,"Community: Spend Unauthoruzed");
        //WrappedToken recipient_token = WrappedToken(config.platform_token);
        require(_amount > 0,"Community: Spend amount Must be greater than 0");
        require(config.spend_limit >= _amount,"Community: Spend amount sent is less than the minimum value");
        TransferHelper.safeTransfer(config.platform_token,_recipient,_amount);
        emit spend_log(_recipient,_amount);
    }

    function QueryConfig() public view returns (Config memory){
        return config;
    }
}
