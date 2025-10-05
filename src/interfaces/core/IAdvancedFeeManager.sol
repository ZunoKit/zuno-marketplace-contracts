// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IAdvancedFeeManager
 * @notice Interface for Advanced Fee Manager
 */
interface IAdvancedFeeManager {
    function calculateFee(uint256 salePrice) external view returns (uint256);

    function getTakerFee() external view returns (uint256);

    function getMakerFee() external view returns (uint256);

    function getFeeRecipient() external view returns (address);

    function setTakerFee(uint256 newFee) external;

    function setMakerFee(uint256 newFee) external;
}
