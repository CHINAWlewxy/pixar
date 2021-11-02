pragma solidity ^0.6.0;

interface ItokenId{
    function getTokenId(bytes calldata data,address sender) external returns (uint256);
    function getRandomNumber(bytes calldata data,address sender) external returns (uint256);
}
