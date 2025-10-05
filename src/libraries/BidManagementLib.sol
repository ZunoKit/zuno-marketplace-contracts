// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ArrayUtilsLib} from "./ArrayUtilsLib.sol";

/**
 * @title BidManagementLib
 * @notice Library for managing bids in auction systems
 * @dev Centralizes bid storage, validation, and refund logic
 */
library BidManagementLib {
    // ============================================================================
    // ERRORS
    // ============================================================================

    error BidManagement__BidNotFound();
    error BidManagement__RefundFailed();
    error BidManagement__InsufficientBalance();
    error BidManagement__InvalidBidder();
    error BidManagement__BidAlreadyExists();

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Individual bid information
     */
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        bool isActive;
        bool isRefunded;
    }

    /**
     * @notice Bid storage for an auction
     */
    struct BidStorage {
        mapping(address => Bid) bids; // bidder => bid
        address[] bidders; // array of all bidders
        address highestBidder;
        uint256 highestBidAmount;
        uint256 totalBids;
        mapping(address => uint256) pendingRefunds; // bidder => refund amount
    }

    /**
     * @notice Bid placement parameters
     */
    struct BidPlacementParams {
        address bidder;
        uint256 bidAmount;
        uint256 currentHighestBid;
        address currentHighestBidder;
        bool isFirstBid;
    }

    /**
     * @notice Bid placement result
     */
    struct BidPlacementResult {
        bool success;
        address previousHighestBidder;
        uint256 previousHighestBid;
        uint256 refundAmount;
        bool needsRefund;
        string errorMessage;
    }

    // ============================================================================
    // BID PLACEMENT FUNCTIONS
    // ============================================================================

    /**
     * @notice Places a new bid in the auction
     * @param storage_ Bid storage reference
     * @param params Bid placement parameters
     * @return result Bid placement result
     */
    function placeBid(BidStorage storage storage_, BidPlacementParams memory params)
        internal
        returns (BidPlacementResult memory result)
    {
        // Validate bidder
        if (params.bidder == address(0)) {
            result.errorMessage = "Invalid bidder address";
            return result;
        }

        // Check if bidder already has an active bid
        if (storage_.bids[params.bidder].isActive) {
            // Update existing bid
            return _updateExistingBid(storage_, params);
        } else {
            // Place new bid
            return _placeNewBid(storage_, params);
        }
    }

    /**
     * @notice Updates an existing bid from the same bidder
     * @param storage_ Bid storage reference
     * @param params Bid placement parameters
     * @return result Bid placement result
     */
    function _updateExistingBid(BidStorage storage storage_, BidPlacementParams memory params)
        private
        returns (BidPlacementResult memory result)
    {
        Bid storage existingBid = storage_.bids[params.bidder];

        // Calculate total bid amount (existing + new)
        uint256 totalBidAmount = existingBid.amount + params.bidAmount;

        // Store previous highest bid info for refund
        result.previousHighestBidder = storage_.highestBidder;
        result.previousHighestBid = storage_.highestBidAmount;

        // Update bid
        existingBid.amount = totalBidAmount;
        existingBid.timestamp = block.timestamp;

        // Update highest bid if this bidder becomes the highest
        if (totalBidAmount > storage_.highestBidAmount) {
            storage_.highestBidder = params.bidder;
            storage_.highestBidAmount = totalBidAmount;

            // Clear pending refunds for this bidder (they're now winning)
            storage_.pendingRefunds[params.bidder] = 0;

            // Set up refund for previous highest bidder
            if (result.previousHighestBidder != address(0) && result.previousHighestBidder != params.bidder) {
                storage_.pendingRefunds[result.previousHighestBidder] = result.previousHighestBid;
                result.needsRefund = true;
                result.refundAmount = result.previousHighestBid;
            }
        }

        result.success = true;
        return result;
    }

    /**
     * @notice Places a new bid from a new bidder
     * @param storage_ Bid storage reference
     * @param params Bid placement parameters
     * @return result Bid placement result
     */
    function _placeNewBid(BidStorage storage storage_, BidPlacementParams memory params)
        private
        returns (BidPlacementResult memory result)
    {
        // Store previous highest bid info for refund
        result.previousHighestBidder = storage_.highestBidder;
        result.previousHighestBid = storage_.highestBidAmount;

        // Create new bid
        storage_.bids[params.bidder] = Bid({
            bidder: params.bidder,
            amount: params.bidAmount,
            timestamp: block.timestamp,
            isActive: true,
            isRefunded: false
        });

        // Add to bidders array
        storage_.bidders.push(params.bidder);
        storage_.totalBids++;

        // Update highest bid
        storage_.highestBidder = params.bidder;
        storage_.highestBidAmount = params.bidAmount;

        // Set up refund for previous highest bidder
        if (result.previousHighestBidder != address(0)) {
            storage_.pendingRefunds[result.previousHighestBidder] = result.previousHighestBid;
            result.needsRefund = true;
            result.refundAmount = result.previousHighestBid;
        }

        result.success = true;
        return result;
    }

    // ============================================================================
    // REFUND FUNCTIONS
    // ============================================================================

    /**
     * @notice Processes refund for a bidder
     * @param storage_ Bid storage reference
     * @param bidder Bidder address
     * @return refundAmount Amount refunded
     */
    function processRefund(BidStorage storage storage_, address bidder) internal returns (uint256 refundAmount) {
        refundAmount = storage_.pendingRefunds[bidder];

        if (refundAmount > 0) {
            storage_.pendingRefunds[bidder] = 0;
            storage_.bids[bidder].isRefunded = true;

            // Transfer refund
            (bool success,) = payable(bidder).call{value: refundAmount}("");
            if (!success) {
                // Restore pending refund if transfer fails
                storage_.pendingRefunds[bidder] = refundAmount;
                storage_.bids[bidder].isRefunded = false;
                revert BidManagement__RefundFailed();
            }
        }

        return refundAmount;
    }

    /**
     * @notice Processes refunds for all losing bidders
     * @param storage_ Bid storage reference
     * @param excludeBidder Bidder to exclude from refunds (usually winner)
     * @return totalRefunded Total amount refunded
     */
    function processAllRefunds(BidStorage storage storage_, address excludeBidder)
        internal
        returns (uint256 totalRefunded)
    {
        for (uint256 i = 0; i < storage_.bidders.length; i++) {
            address bidder = storage_.bidders[i];
            if (bidder != excludeBidder && storage_.pendingRefunds[bidder] > 0) {
                totalRefunded += processRefund(storage_, bidder);
            }
        }
        return totalRefunded;
    }

    // ============================================================================
    // QUERY FUNCTIONS
    // ============================================================================

    /**
     * @notice Gets bid information for a bidder
     * @param storage_ Bid storage reference
     * @param bidder Bidder address
     * @return bid Bid information
     */
    function getBid(BidStorage storage storage_, address bidder) internal view returns (Bid memory bid) {
        return storage_.bids[bidder];
    }

    /**
     * @notice Gets pending refund amount for a bidder
     * @param storage_ Bid storage reference
     * @param bidder Bidder address
     * @return refundAmount Pending refund amount
     */
    function getPendingRefund(BidStorage storage storage_, address bidder)
        internal
        view
        returns (uint256 refundAmount)
    {
        return storage_.pendingRefunds[bidder];
    }

    /**
     * @notice Gets highest bid information
     * @param storage_ Bid storage reference
     * @return bidder Highest bidder address
     * @return amount Highest bid amount
     */
    function getHighestBid(BidStorage storage storage_) internal view returns (address bidder, uint256 amount) {
        return (storage_.highestBidder, storage_.highestBidAmount);
    }

    /**
     * @notice Gets all bidders
     * @param storage_ Bid storage reference
     * @return bidders Array of all bidder addresses
     */
    function getAllBidders(BidStorage storage storage_) internal view returns (address[] memory bidders) {
        return storage_.bidders;
    }

    /**
     * @notice Gets total number of bids
     * @param storage_ Bid storage reference
     * @return totalBids Total number of bids
     */
    function getTotalBids(BidStorage storage storage_) internal view returns (uint256 totalBids) {
        return storage_.totalBids;
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @notice Checks if an auction has an active bid
     * @param s_bids The bids mapping
     * @param m_auctionId The auction ID to check
     * @return True if the auction has an active bid, false otherwise
     */
    function hasActiveBid(mapping(bytes32 => Bid) storage s_bids, bytes32 m_auctionId) internal view returns (bool) {
        Bid storage bid = s_bids[m_auctionId];
        return bid.bidder != address(0) && bid.amount > 0;
    }

    /**
     * @notice Checks if a bidder is the current highest bidder
     * @param storage_ Bid storage reference
     * @param bidder Bidder address
     * @return isHighest True if bidder is highest
     */
    function isHighestBidder(BidStorage storage storage_, address bidder) internal view returns (bool isHighest) {
        return storage_.highestBidder == bidder;
    }

    /**
     * @notice Resets bid storage (for auction cancellation)
     * @param storage_ Bid storage reference
     */
    function resetBidStorage(BidStorage storage storage_) internal {
        // Mark all bids as inactive
        for (uint256 i = 0; i < storage_.bidders.length; i++) {
            address bidder = storage_.bidders[i];
            storage_.bids[bidder].isActive = false;
        }

        // Reset highest bid info
        storage_.highestBidder = address(0);
        storage_.highestBidAmount = 0;
    }

    /**
     * @notice Creates bid placement parameters
     * @param bidder Bidder address
     * @param bidAmount Bid amount
     * @param currentHighestBid Current highest bid
     * @param currentHighestBidder Current highest bidder
     * @param isFirstBid Whether this is the first bid
     * @return params Bid placement parameters
     */
    function createBidPlacementParams(
        address bidder,
        uint256 bidAmount,
        uint256 currentHighestBid,
        address currentHighestBidder,
        bool isFirstBid
    ) internal pure returns (BidPlacementParams memory params) {
        return BidPlacementParams({
            bidder: bidder,
            bidAmount: bidAmount,
            currentHighestBid: currentHighestBid,
            currentHighestBidder: currentHighestBidder,
            isFirstBid: isFirstBid
        });
    }
}
