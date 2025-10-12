// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IBaseFee
 * @notice Interface for Base Fee contract
 */
interface IBaseFee {
    function getTakerFee() external view returns (uint256);

    function getBPS_DENOMINATOR() external pure returns (uint256);

    function getMarketplaceWallet() external view returns (address);
}
