// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title PaymentDistributionLib
 * @notice Library for handling payment distribution across marketplace and auction systems
 * @dev Centralizes payment logic to reduce code duplication and gas costs
 */
library PaymentDistributionLib {
    // ============================================================================
    // ERRORS
    // ============================================================================

    error PaymentDistribution__InsufficientBalance();
    error PaymentDistribution__TransferFailed();
    error PaymentDistribution__ZeroAddress();
    error PaymentDistribution__InvalidAmount();

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Payment distribution data structure
     */
    struct PaymentData {
        address seller;
        address royaltyReceiver;
        address marketplaceWallet;
        uint256 totalAmount;
        uint256 sellerAmount;
        uint256 marketplaceFee;
        uint256 royaltyAmount;
    }

    /**
     * @notice Fee calculation parameters
     */
    struct FeeParams {
        uint256 salePrice;
        uint256 marketplaceFeeRate; // in basis points
        uint256 royaltyRate; // in basis points
        uint256 bpsDenominator; // typically 10000
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event PaymentDistributed(
        address indexed seller,
        address indexed buyer,
        uint256 totalAmount,
        uint256 sellerAmount,
        uint256 marketplaceFee,
        uint256 royaltyAmount
    );

    // ============================================================================
    // MAIN FUNCTIONS
    // ============================================================================

    /**
     * @notice Distributes payment to all parties (seller, marketplace, royalty receiver)
     * @param data Payment distribution data
     */
    function distributePayment(PaymentData memory data) internal {
        _validatePaymentData(data);

        // Transfer marketplace fee
        if (data.marketplaceFee > 0) {
            _safeTransfer(data.marketplaceWallet, data.marketplaceFee);
        }

        // Transfer royalty
        if (data.royaltyAmount > 0 && data.royaltyReceiver != address(0)) {
            _safeTransfer(data.royaltyReceiver, data.royaltyAmount);
        }

        // Transfer remaining amount to seller
        if (data.sellerAmount > 0) {
            _safeTransfer(data.seller, data.sellerAmount);
        }
    }

    /**
     * @notice Calculates payment distribution amounts
     * @param params Fee calculation parameters
     * @param seller Address of the seller
     * @param royaltyReceiver Address of the royalty receiver
     * @param marketplaceWallet Address of the marketplace wallet
     * @return data Calculated payment distribution data
     */
    function calculatePaymentDistribution(
        FeeParams memory params,
        address seller,
        address royaltyReceiver,
        address marketplaceWallet
    ) internal pure returns (PaymentData memory data) {
        // Calculate marketplace fee
        uint256 marketplaceFee = (params.salePrice * params.marketplaceFeeRate) / params.bpsDenominator;

        // Calculate royalty
        uint256 royaltyAmount = (params.salePrice * params.royaltyRate) / params.bpsDenominator;

        // Calculate seller amount (remaining after fees)
        uint256 sellerAmount = params.salePrice - marketplaceFee - royaltyAmount;

        // Total amount should equal sale price
        uint256 totalAmount = params.salePrice;

        return PaymentData({
            seller: seller,
            royaltyReceiver: royaltyReceiver,
            marketplaceWallet: marketplaceWallet,
            totalAmount: totalAmount,
            sellerAmount: sellerAmount,
            marketplaceFee: marketplaceFee,
            royaltyAmount: royaltyAmount
        });
    }

    /**
     * @notice Calculates the total amount buyer needs to pay (including fees)
     * @param basePrice Base price of the item
     * @param takerFeeRate Taker fee rate in basis points
     * @param royaltyRate Royalty rate in basis points
     * @param bpsDenominator Basis points denominator
     * @return totalPrice Total price buyer needs to pay
     */
    function calculateBuyerPrice(uint256 basePrice, uint256 takerFeeRate, uint256 royaltyRate, uint256 bpsDenominator)
        internal
        pure
        returns (uint256 totalPrice)
    {
        uint256 takerFee = (basePrice * takerFeeRate) / bpsDenominator;
        uint256 royalty = (basePrice * royaltyRate) / bpsDenominator;
        return basePrice + takerFee + royalty;
    }

    // ============================================================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================================================

    /**
     * @notice Validates payment data before distribution
     * @param data Payment data to validate
     */
    function _validatePaymentData(PaymentData memory data) private pure {
        if (data.seller == address(0)) revert PaymentDistribution__ZeroAddress();
        if (data.marketplaceWallet == address(0)) revert PaymentDistribution__ZeroAddress();
        if (data.totalAmount == 0) revert PaymentDistribution__InvalidAmount();

        // Ensure amounts add up correctly
        uint256 calculatedTotal = data.sellerAmount + data.marketplaceFee + data.royaltyAmount;
        if (calculatedTotal != data.totalAmount) {
            revert PaymentDistribution__InvalidAmount();
        }
    }

    /**
     * @notice Safely transfers ETH to an address
     * @param to Address to transfer to
     * @param amount Amount to transfer
     */
    function _safeTransfer(address to, uint256 amount) private {
        if (address(this).balance < amount) {
            revert PaymentDistribution__InsufficientBalance();
        }

        (bool success,) = payable(to).call{value: amount}("");
        if (!success) {
            revert PaymentDistribution__TransferFailed();
        }
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @notice Calculates percentage of an amount
     * @param amount Base amount
     * @param percentage Percentage in basis points
     * @param denominator Basis points denominator
     * @return result Calculated percentage amount
     */
    function calculatePercentage(uint256 amount, uint256 percentage, uint256 denominator)
        internal
        pure
        returns (uint256 result)
    {
        return (amount * percentage) / denominator;
    }

    /**
     * @notice Validates that fee rates don't exceed maximum allowed
     * @param feeRate Fee rate to validate
     * @param maxFeeRate Maximum allowed fee rate
     */
    function validateFeeRate(uint256 feeRate, uint256 maxFeeRate) internal pure {
        if (feeRate > maxFeeRate) {
            revert PaymentDistribution__InvalidAmount();
        }
    }
}
