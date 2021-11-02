// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../token/ControlledTokenProxyFactory.sol";

contract BuildToken {

    event CreatedControlledToken(address indexed token);

    struct ControlledTokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        TokenControllerInterface controller;
        //address controller;
    }

    ControlledTokenProxyFactory public controlledTokenProxyFactory;

    constructor(ControlledTokenProxyFactory _controlledTokenProxyFactory) public {
        require(address(_controlledTokenProxyFactory) != address(0),"BlindBox Err:ControlledToken Not Zero");
        controlledTokenProxyFactory = _controlledTokenProxyFactory;
    }

    function createControlledToken(
                                  ControlledTokenConfig calldata config
                                  ) external returns(ControlledToken){
        ControlledToken token = controlledTokenProxyFactory.create();
        //ControlledToken token;
        token.initialize(
                         config.name,
                         config.symbol,
                         config.decimals,
                         config.controller
                         );
        emit CreatedControlledToken(address(token));
        return token;
    }
    //TokenControllerInterface public  controller;
    //function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual  {
    //    controller.beforeTokenTransfer(from, to, amount);
    //}
}
