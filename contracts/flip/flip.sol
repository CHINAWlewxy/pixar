// SPDX-License-Identifier: MIT
pragma solidity ^0.6.5;

import "../token/WrappedToken.sol";
import "../TransferHelper.sol";
import "../token/ControlledToken.sol";
import "../nft/nft.sol";
import "../blindBox/BlindBox.sol";
import "../ItokenId/ItokenId.sol";

contract flip {
    struct Config{
        address owner;
        address lable_address;
        address platform_token;
        address key_token;
        address prize_pool;
        address itokenId;
        nft  nft_token;
        BlindBox blind_box;
    }

    Config public config;

    string public lastresult;
    uint public lastblocknumberused;
    bytes32 public lastblockhashused;

    constructor(
        address _lableAddress,
        address platform_token,
        address nft_token,
        address payable _blind_box,
        address prize_pool,
        address itokenId) public
    {
        config.owner = msg.sender;
        config.lable_address = _lableAddress;
        config.platform_token = platform_token;
        config.nft_token = nft(nft_token);
        config.blind_box = BlindBox(_blind_box);
        config.itokenId = itokenId;
        config.prize_pool = prize_pool;
        lastresult = "no wagers yet";
    }

    function init(address _key_token) external {
        //require( msg.sender == config.owner, "Flip Err:unauthorized");
        require(config.key_token == address(0),"Flip Err:Can not be re-initialized");
        config.key_token = _key_token;
    }

    event betAndFlipLog(string);
    function betAndFlip(uint256 value, uint256 num) external
    {
        require(msg.sender == tx.origin,"Flip Err:request failed");
        require(value == 10*10**18 ||value == 100*10**18 || value == 1000*10**18, "The amount should be 10 or 100 or 1000");
        require(num == 0 || num == 1, "parameter is incorrect");

        WrappedToken platform_token = WrappedToken(config.platform_token);

        uint256 amount = platform_token.allowance(msg.sender,address(this));
        require(amount >= value,"flip Err:amount cannot than allowance");

        uint256 prizeAmount = value*95/100;
        TransferHelper.safeTransferFrom(config.platform_token,msg.sender,config.prize_pool,prizeAmount);

        TransferHelper.safeTransferFrom(config.platform_token,msg.sender,config.lable_address,value-prizeAmount);

        uint256 hashymchasherton = ItokenId(config.itokenId).getRandomNumber(msg.data, msg.sender);
        uint256 rand = hashymchasherton % 2;
        if( rand == num )
        {
            lastresult = "win";
            TransferHelper.safeTransfer(config.platform_token,msg.sender, value * 95 * 2 /100);
        }
        else
        {
            lastresult = "loss";
            if (value == 10*10**18)
            {
                (uint256[] memory seriesIds, uint256 lenId) = config.blind_box.QuerySeriesIdsNotNull();
                uint256 randSeridId = hashymchasherton % lenId;
                config.nft_token.Draw(msg.sender, 1, 0, seriesIds[randSeridId],
                                      hashymchasherton);
            }else if (value == 100*10**18)
            {
                config.blind_box.mintKey(msg.sender,1);
            }
            else
            {
                config.blind_box.mintKey(msg.sender,10);
            }
        }
        emit betAndFlipLog(lastresult);
    }

    function getLastBlockNumberUsed() external view returns (uint)
    {
        return lastblocknumberused;
    }

    function getLastBlockHashUsed() external view returns (bytes32)
    {
        return lastblockhashused;
    }

    function getResultOfLastFlip() external view returns (string memory)
    {
        return lastresult;
    }

}
