// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './WrappedToken.sol';
import '../TransferHelper.sol';

contract WrappedPlatformToken is WrappedToken {
    using SafeMath for uint256;
    event release_log(uint256,uint256);
    constructor(
                address _mint_address,
                uint256 _duration,
                address _beneficiary,
                uint256 _quantity,
                uint256 _total
                ) public WrappedToken(_mint_address, "Pix token",
                                      "PIX",_total,_quantity,address(this)) {
        released = _quantity.div(_duration);
        config = Config(now,0,_duration,_beneficiary,_quantity,_total);
    }

    struct Config {
        uint256 start; //start time
        uint256 end;  // last send reward
        uint256 duration; //Duration in seconds
        address beneficiary; // Earning account
        uint256 quantity; //quantity retained
        uint256 total; //total amount
    }

    Config public config;

    uint256 public released;

    function release()public{
        uint256 done;
        uint256 time_unix;
        (done,time_unix) = _deal();
        uint256 balance = WrappedToken(address(this)).balanceOf(address(this));
        require(balance > 0 ,"Err:platform not enough");
        if (done > balance){
            done = balance;
        }
        TransferHelper.safeTransfer(address(this),config.beneficiary,done);
        config.end = time_unix;
        emit release_log(done,time_unix);
    }

    function seeRelease()public view returns (uint256,uint256){
        return _deal();
    }

    function _deal() internal view returns (uint256,uint256){
        uint256 time = config.end;
        if (config.end == 0){
            time = config.start;
        }
        uint256 now_time = now;
        uint256 duration = now_time.sub(time);
        return (duration.mul(released),now_time);
    }

}
