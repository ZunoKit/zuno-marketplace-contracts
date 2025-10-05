// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IFeeRegistry
 * @notice Interface for unified fee management across the marketplace
 * @dev Centralizes all fee-related calculations and queries
 */
interface IFeeRegistry {
    /**
     * @notice Fee breakdown structure
     */
    struct FeeBreakdown {
        uint256 platformFee; // Marketplace platform fee
        uint256 royaltyFee; // Creator royalty fee
        address royaltyRecipient; // Recipient of royalty
        uint256 totalFees; // Total fees (platform + royalty)
        uint256 sellerProceeds; // Amount seller receives
    }

    /**
     * @notice Emitted when fee contracts are updated
     */
    event FeeContractsUpdated(address baseFee, address feeManager, address royaltyManager);

    /**
     * @notice Calculate all fees for a given sale
     * @param nftContract The NFT contract address
     * @param tokenId The token ID
     * @param salePrice The sale price
     * @return breakdown Complete fee breakdown
     */
    function calculateAllFees(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (FeeBreakdown memory breakdown);

    /**
     * @notice Calculate platform fee only
     * @param salePrice The sale price
     * @return Platform fee amount
     */
    function calculatePlatformFee(uint256 salePrice) external view returns (uint256);

    /**
     * @notice Calculate royalty fee only
     * @param nftContract The NFT contract address
     * @param tokenId The token ID
     * @param salePrice The sale price
     * @return recipient Royalty recipient address
     * @return amount Royalty amount
     */
    function calculateRoyalty(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address recipient, uint256 amount);

    /**
     * @notice Get current platform fee percentage
     * @return Fee percentage in basis points (e.g., 200 = 2%)
     */
    function getPlatformFeePercentage() external view returns (uint256);

    /**
     * @notice Get the base fee contract address
     * @return Base fee contract address
     */
    function getBaseFeeContract() external view returns (address);

    /**
     * @notice Get the fee manager contract address
     * @return Fee manager contract address
     */
    function getFeeManagerContract() external view returns (address);

    /**
     * @notice Get the royalty manager contract address
     * @return Royalty manager contract address
     */
    function getRoyaltyManagerContract() external view returns (address);

    /**
     * @notice Update fee contracts
     * @param baseFee New base fee contract address
     * @param feeManager New fee manager contract address
     * @param royaltyManager New royalty manager contract address
     */
    function updateFeeContracts(address baseFee, address feeManager, address royaltyManager) external;
}
