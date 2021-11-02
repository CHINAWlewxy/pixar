pragma solidity ^0.6.0;
import "./ItokenId.sol";

contract tokenIdTest {
    address public tokenId;
    //ItokenId tokenIdContract;
    constructor (address _tokenIdAddr) public {
        tokenId = _tokenIdAddr;
    }
    event logs(uint256);
    function usetokenId() public returns (uint256 result){
        result = ItokenId(tokenId).getTokenId(msg.data, msg.sender);
        emit logs(result);
        return result;
    }
}
