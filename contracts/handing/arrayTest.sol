// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "./LibArray.sol";

contract TestArray {
     uint256[][] public array;
     constructor()public{}
     function f() public{
         uint256[] memory val = new uint256[](5);
         val[0] = 1;
         val[1] = 2;
         val[2] = 3;
         LibArray.addValue(array,val);
     }
     function e() public{
         uint256[] memory val = new uint256[](5);
         val[0] = 4;
         val[1] = 5;
         LibArray.addValue(array,val);
     }
     event log(uint256);
     function d() public returns (uint256){
         emit log(array[0][1]);
         return array[0][1];
     }
     event logs(uint256,uint256,uint256,uint256,uint256,uint256);
     function s() public returns (uint256[][] memory){
         emit logs(array[0][0],array[0][1],array[1][0],array[1][1],array[0].length,array.length);
         return array;
     }

}
