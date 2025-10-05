// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IAdvancedRoyaltyManager
 * @notice Interface for Advanced Royalty Manager
 */
interface IAdvancedRoyaltyManager {
    function getRoyaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address recipient, uint256 amount);

    function setRoyalty(address nftContract, address recipient, uint96 royaltyBps) external;

    function deleteRoyalty(address nftContract) external;
}
