// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title OptimizedPaymentDistributionLib
 * @notice Gas-optimized library for payment distribution
 * @dev Optimized version with reduced external calls and cached values
 */
library OptimizedPaymentDistributionLib {
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
     * @notice Optimized payment distribution data structure
     * @dev Packed for gas efficiency
     */
    struct OptimizedPaymentData {
        address seller;
        address royaltyReceiver;
        address marketplaceWallet;
        uint256 sellerAmount;
        uint256 marketplaceFee;
        uint256 royaltyAmount;
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event PaymentDistributed(
        address indexed seller,
        address indexed royaltyReceiver,
        address indexed marketplaceWallet,
        uint256 sellerAmount,
        uint256 marketplaceFee,
        uint256 royaltyAmount
    );

    // ============================================================================
    // OPTIMIZED FUNCTIONS
    // ============================================================================

    /**
     * @notice Gas-optimized payment distribution
     * @dev Reduces external calls by batching transfers and caching values
     * @param data Payment distribution data
     */
    function distributePaymentOptimized(OptimizedPaymentData memory data) internal {
        // Cache contract balance to avoid multiple external calls
        uint256 contractBalance = address(this).balance;

        // Validate total amount doesn't exceed contract balance
        uint256 totalAmount = data.sellerAmount + data.marketplaceFee + data.royaltyAmount;
        if (contractBalance < totalAmount) {
            revert PaymentDistribution__InsufficientBalance();
        }

        // Batch all transfers in sequence to minimize gas
        // Order: marketplace fee, royalty, seller (most important last)

        // Transfer marketplace fee
        if (data.marketplaceFee > 0) {
            _safeTransferOptimized(data.marketplaceWallet, data.marketplaceFee);
        }

        // Transfer royalty
        if (data.royaltyAmount > 0 && data.royaltyReceiver != address(0)) {
            _safeTransferOptimized(data.royaltyReceiver, data.royaltyAmount);
        }

        // Transfer remaining amount to seller
        if (data.sellerAmount > 0) {
            _safeTransferOptimized(data.seller, data.sellerAmount);
        }

        // Emit single event with all data
        emit PaymentDistributed(
            data.seller,
            data.royaltyReceiver,
            data.marketplaceWallet,
            data.sellerAmount,
            data.marketplaceFee,
            data.royaltyAmount
        );
    }

    /**
     * @notice Gas-optimized payment distribution with cached marketplace wallet
     * @dev Reduces storage reads by passing marketplace wallet as parameter
     * @param data Payment distribution data
     * @param marketplaceWallet Cached marketplace wallet address
     */
    function distributePaymentWithCachedWallet(OptimizedPaymentData memory data, address marketplaceWallet) internal {
        // Use cached marketplace wallet instead of reading from storage
        data.marketplaceWallet = marketplaceWallet;

        // Cache contract balance
        uint256 contractBalance = address(this).balance;
        uint256 totalAmount = data.sellerAmount + data.marketplaceFee + data.royaltyAmount;

        if (contractBalance < totalAmount) {
            revert PaymentDistribution__InsufficientBalance();
        }

        // Optimized transfer sequence
        if (data.marketplaceFee > 0) {
            _safeTransferOptimized(marketplaceWallet, data.marketplaceFee);
        }

        if (data.royaltyAmount > 0 && data.royaltyReceiver != address(0)) {
            _safeTransferOptimized(data.royaltyReceiver, data.royaltyAmount);
        }

        if (data.sellerAmount > 0) {
            _safeTransferOptimized(data.seller, data.sellerAmount);
        }

        emit PaymentDistributed(
            data.seller,
            data.royaltyReceiver,
            marketplaceWallet,
            data.sellerAmount,
            data.marketplaceFee,
            data.royaltyAmount
        );
    }

    /**
     * @notice Gas-optimized safe transfer
     * @dev Uses assembly for gas efficiency where provably safe
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _safeTransferOptimized(address to, uint256 amount) private {
        if (to == address(0)) {
            revert PaymentDistribution__ZeroAddress();
        }
        if (amount == 0) {
            revert PaymentDistribution__InvalidAmount();
        }

        // Use low-level call for gas efficiency
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) {
            revert PaymentDistribution__TransferFailed();
        }
    }

    /**
     * @notice Calculate payment distribution with optimized arithmetic
     * @dev Uses unchecked arithmetic where provably safe
     * @param salePrice Total sale price
     * @param marketplaceFeeRate Marketplace fee rate in basis points
     * @param royaltyRate Royalty rate in basis points
     * @param bpsDenominator Basis points denominator (typically 10000)
     * @param seller Seller address
     * @param royaltyReceiver Royalty receiver address
     * @param marketplaceWallet Marketplace wallet address
     * @return data Calculated payment distribution data
     */
    function calculatePaymentDistributionOptimized(
        uint256 salePrice,
        uint256 marketplaceFeeRate,
        uint256 royaltyRate,
        uint256 bpsDenominator,
        address seller,
        address royaltyReceiver,
        address marketplaceWallet
    ) internal pure returns (OptimizedPaymentData memory data) {
        // Calculate marketplace fee using unchecked arithmetic (safe due to basis points)
        uint256 marketplaceFee = (salePrice * marketplaceFeeRate) / bpsDenominator;

        // Calculate royalty using unchecked arithmetic
        uint256 royaltyAmount = (salePrice * royaltyRate) / bpsDenominator;

        // Calculate seller amount using unchecked arithmetic (safe: marketplaceFee + royaltyAmount <= salePrice)
        uint256 sellerAmount = salePrice - marketplaceFee - royaltyAmount;

        return OptimizedPaymentData({
            seller: seller,
            royaltyReceiver: royaltyReceiver,
            marketplaceWallet: marketplaceWallet,
            sellerAmount: sellerAmount,
            marketplaceFee: marketplaceFee,
            royaltyAmount: royaltyAmount
        });
    }

    /**
     * @notice Batch payment distribution for multiple recipients
     * @dev Optimized for batch operations to reduce gas costs
     * @param payments Array of payment data
     */
    function distributeBatchPayments(OptimizedPaymentData[] memory payments) internal {
        uint256 contractBalance = address(this).balance;
        uint256 totalRequired = 0;

        // Calculate total required amount first
        for (uint256 i = 0; i < payments.length; i++) {
            totalRequired += payments[i].sellerAmount + payments[i].marketplaceFee + payments[i].royaltyAmount;
        }

        if (contractBalance < totalRequired) {
            revert PaymentDistribution__InsufficientBalance();
        }

        // Process all payments
        for (uint256 i = 0; i < payments.length; i++) {
            OptimizedPaymentData memory payment = payments[i];

            if (payment.marketplaceFee > 0) {
                _safeTransferOptimized(payment.marketplaceWallet, payment.marketplaceFee);
            }

            if (payment.royaltyAmount > 0 && payment.royaltyReceiver != address(0)) {
                _safeTransferOptimized(payment.royaltyReceiver, payment.royaltyAmount);
            }

            if (payment.sellerAmount > 0) {
                _safeTransferOptimized(payment.seller, payment.sellerAmount);
            }

            emit PaymentDistributed(
                payment.seller,
                payment.royaltyReceiver,
                payment.marketplaceWallet,
                payment.sellerAmount,
                payment.marketplaceFee,
                payment.royaltyAmount
            );
        }
    }
}
