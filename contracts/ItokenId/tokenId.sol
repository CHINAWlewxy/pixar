pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../nft/IPancakePair.sol";

contract tokenId is VRFConsumerBase,OwnableUpgradeable{
    address private mine;

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 private linkRand;

    IPancakePair[] private lp_list; //top 10 liquidity pools

    constructor (address _lp_token1,
                 address _lp_token2,
                 address _lp_token3,
                 address _lp_token4,
                 address _lp_token5,
                 address _lp_token6,
                 address _lp_token7,
                 address _lp_token8,
                 address _lp_token9,
                 address _lp_token10,
                 address _owner,
                 address _vrfCoordinator,
                 address _linkToken,
                 bytes32 _keyHash,
                 uint256 _fee) VRFConsumerBase(
                         _vrfCoordinator,
                         _linkToken
                         )public{
        keyHash = _keyHash;
        fee = _fee;
        mine = _owner;
        lp_list.push(IPancakePair(_lp_token1));
        lp_list.push(IPancakePair(_lp_token2));
        lp_list.push(IPancakePair(_lp_token3));
        lp_list.push(IPancakePair(_lp_token4));
        lp_list.push(IPancakePair(_lp_token5));
        lp_list.push(IPancakePair(_lp_token6));
        lp_list.push(IPancakePair(_lp_token7));
        lp_list.push(IPancakePair(_lp_token8));
        lp_list.push(IPancakePair(_lp_token9));
        lp_list.push(IPancakePair(_lp_token10));
    }

    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        linkRand = randomness;
    }

    //return a random number .
    function getTokenId(bytes calldata data,address sender) external  returns (uint256 result){
        uint256 price = getSwapPrice();
        uint256 seed = uint256(keccak256(abi.encodePacked(
            (block.timestamp).add
            (block.difficulty).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
            (block.gaslimit).add
            (block.number).add
            (linkRand).add(price))));
        uint256 seek = uint256(keccak256(abi.encodePacked(sender,data))) % 100;
        result = (seed - seek) % 100 + 1;
        linkRand++;
        return result;
    }

        //return a random number .
    function getRandomNumber(bytes calldata data,address sender) external view returns (uint256 result){
        uint256 price = getSwapPrice();
        uint256 seed = uint256(keccak256(abi.encodePacked(
            (block.timestamp).add
            (block.difficulty).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
            (block.gaslimit).add
            (block.number).add
            (linkRand).add(price))));
        uint256 seek = uint256(keccak256(abi.encodePacked(sender,data))) % 100;
        return (seed.add(seek));
    }

    function getSwapPrice() private view returns (uint256) {
        uint256 result = 0;
        for (uint i = 0; i < 10;i++){
            (uint256 reserve0, uint256 reserve1,) = lp_list[i].getReserves();
            result = result.add(reserve0>reserve1?reserve0.sub(reserve1):reserve1.sub(reserve0));
        }

        return result;
    }

    function ResetPancakeLP(uint _index,address _lp_token) external {
        require(msg.sender == mine,"Err:Inoperable");
        lp_list[_index] = IPancakePair(_lp_token);
    }

}
