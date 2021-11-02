pragma solidity ^0.6.0;

interface BlindBoxPromotions{
    function QueryDraws(uint256 _series_id) external view returns (uint256[] memory);
    function QueryLevels(uint256 _series_id) external view returns (uint256[] memory);
    function QueryMix(uint256 _series_id) external view returns (uint256[] memory);
}
