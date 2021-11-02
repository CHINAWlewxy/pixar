// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedToken is ERC20, Ownable {
    using SafeMath for uint256;
    event Burn(address indexed _sender, address indexed _to, uint256 amount);
    address public mint_address;

    constructor( address mint,
                 string memory name,
                 string memory symbol,
                 uint256 amount,
                 uint256 quantity,
                 address quantity_address
        ) public ERC20(name, symbol) {
        _mint(mint, amount.sub(quantity));
        _mint(quantity_address,quantity);
        //mint_address = mint;
    }

    function burn(uint256 amount, address to) public {
        _burn(_msgSender(), amount);

        emit Burn(_msgSender(), to, amount);
    }
}
