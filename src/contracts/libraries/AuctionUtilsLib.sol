// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {NFTValidationLib} from "./NFTValidationLib.sol";
import {RoyaltyLib} from "./RoyaltyLib.sol";

/**
 * @title AuctionUtilsLib
 * @notice Library for auction validation and calculation utilities
 * @dev Centralizes auction logic to reduce code duplication across auction contracts
 */
library AuctionUtilsLib {
    // ============================================================================
    // ERRORS
    // ============================================================================

    error AuctionUtils__InvalidDuration();
    error AuctionUtils__InvalidStartingPrice();
    error AuctionUtils__InvalidReservePrice();
    error AuctionUtils__InvalidBidIncrement();
    error AuctionUtils__InvalidExtensionTime();
    error AuctionUtils__AuctionNotActive();
    error AuctionUtils__AuctionExpired();
    error AuctionUtils__BidTooLow();
    error AuctionUtils__InvalidNFT();

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Auction creation parameters
     */
    struct AuctionCreationParams {
        address nftContract;
        uint256 tokenId;
        uint256 amount; // 1 for ERC721, actual amount for ERC1155
        uint256 startingPrice;
        uint256 reservePrice;
        uint256 duration;
        uint256 bidIncrement;
        uint256 extensionTime;
        address seller;
        address spender; // auction contract
    }

    /**
     * @notice Auction validation result
     */
    struct ValidationResult {
        bool isValid;
        string errorMessage;
    }

    /**
     * @notice Bid validation parameters
     */
    struct BidValidationParams {
        uint256 bidAmount;
        uint256 currentHighestBid;
        uint256 minimumBidIncrement;
        uint256 reservePrice;
        uint256 auctionEndTime;
        bool hasReservePrice;
    }

    /**
     * @notice Auction time calculation result
     */
    struct TimeCalculation {
        uint256 endTime;
        uint256 extensionTime;
        bool needsExtension;
        uint256 newEndTime;
    }

    // ============================================================================
    // AUCTION CREATION VALIDATION
    // ============================================================================

    /**
     * @notice Validates auction creation parameters
     * @param params Auction creation parameters
     * @return result Validation result
     */
    function validateAuctionCreation(AuctionCreationParams memory params)
        internal
        view
        returns (ValidationResult memory result)
    {
        // Validate basic parameters
        if (params.duration == 0) {
            result.errorMessage = "Invalid duration";
            return result;
        }

        if (params.startingPrice == 0) {
            result.errorMessage = "Invalid starting price";
            return result;
        }

        if (params.reservePrice > 0 && params.reservePrice < params.startingPrice) {
            result.errorMessage = "Reserve price must be >= starting price";
            return result;
        }

        if (params.bidIncrement == 0) {
            result.errorMessage = "Invalid bid increment";
            return result;
        }

        // Validate NFT ownership and approval
        NFTValidationLib.ValidationParams memory validationParams = NFTValidationLib.createValidationParams(
            params.nftContract, params.tokenId, params.amount, params.seller, params.spender
        );

        NFTValidationLib.ValidationResult memory nftResult = NFTValidationLib.validateNFT(validationParams);
        if (!nftResult.isValid) {
            result.errorMessage = nftResult.errorMessage;
            return result;
        }

        result.isValid = true;
        return result;
    }

    /**
     * @notice Validates auction creation for specific NFT standard
     * @param params Auction creation parameters
     * @param standard NFT standard to validate against
     * @return result Validation result
     */
    function validateAuctionCreationForStandard(
        AuctionCreationParams memory params,
        NFTValidationLib.NFTStandard standard
    ) internal view returns (ValidationResult memory result) {
        // First validate basic auction parameters
        result = validateAuctionCreation(params);
        if (!result.isValid) {
            return result;
        }

        // Validate NFT for specific standard
        NFTValidationLib.ValidationParams memory validationParams = NFTValidationLib.createValidationParams(
            params.nftContract, params.tokenId, params.amount, params.seller, params.spender
        );

        NFTValidationLib.ValidationResult memory nftResult;
        if (standard == NFTValidationLib.NFTStandard.ERC721) {
            nftResult = NFTValidationLib.validateERC721(validationParams);
        } else if (standard == NFTValidationLib.NFTStandard.ERC1155) {
            nftResult = NFTValidationLib.validateERC1155(validationParams);
        } else {
            result.errorMessage = "Unsupported NFT standard";
            result.isValid = false;
            return result;
        }

        if (!nftResult.isValid) {
            result.errorMessage = nftResult.errorMessage;
            result.isValid = false;
            return result;
        }

        return result;
    }

    // ============================================================================
    // BID VALIDATION
    // ============================================================================

    /**
     * @notice Validates a bid against auction parameters
     * @param params Bid validation parameters
     * @return result Validation result
     */
    function validateBid(BidValidationParams memory params) internal view returns (ValidationResult memory result) {
        // Check if auction has ended
        if (block.timestamp >= params.auctionEndTime) {
            result.errorMessage = "Auction has ended";
            return result;
        }

        // Check minimum bid amount
        uint256 minimumBid = params.currentHighestBid + params.minimumBidIncrement;
        if (params.bidAmount < minimumBid) {
            result.errorMessage = "Bid too low";
            return result;
        }

        // Check reserve price if applicable
        if (params.hasReservePrice && params.bidAmount < params.reservePrice) {
            result.errorMessage = "Bid below reserve price";
            return result;
        }

        result.isValid = true;
        return result;
    }

    /**
     * @notice Calculates minimum bid amount for an auction
     * @param currentHighestBid Current highest bid
     * @param bidIncrement Minimum bid increment
     * @param reservePrice Reserve price (0 if none)
     * @return minimumBid Minimum valid bid amount
     */
    function calculateMinimumBid(uint256 currentHighestBid, uint256 bidIncrement, uint256 reservePrice)
        internal
        pure
        returns (uint256 minimumBid)
    {
        uint256 incrementBid = currentHighestBid + bidIncrement;
        return reservePrice > incrementBid ? reservePrice : incrementBid;
    }

    // ============================================================================
    // TIME CALCULATIONS
    // ============================================================================

    /**
     * @notice Calculates auction end time and extension logic
     * @param currentEndTime Current auction end time
     * @param extensionTime Extension time in seconds
     * @param extensionThreshold Time threshold for extension (e.g., 15 minutes)
     * @return calculation Time calculation result
     */
    function calculateAuctionExtension(uint256 currentEndTime, uint256 extensionTime, uint256 extensionThreshold)
        internal
        view
        returns (TimeCalculation memory calculation)
    {
        calculation.endTime = currentEndTime;
        calculation.extensionTime = extensionTime;

        // Check if bid is placed within extension threshold
        if (currentEndTime > block.timestamp && (currentEndTime - block.timestamp) <= extensionThreshold) {
            calculation.needsExtension = true;
            calculation.newEndTime = currentEndTime + extensionTime;
        } else {
            calculation.needsExtension = false;
            calculation.newEndTime = currentEndTime;
        }

        return calculation;
    }

    /**
     * @notice Checks if auction is still active
     * @param endTime Auction end time
     * @return isActive True if auction is still active
     */
    function isAuctionActive(uint256 endTime) internal view returns (bool isActive) {
        return block.timestamp < endTime;
    }

    /**
     * @notice Calculates time remaining in auction
     * @param endTime Auction end time
     * @return timeRemaining Time remaining in seconds (0 if ended)
     */
    function getTimeRemaining(uint256 endTime) internal view returns (uint256 timeRemaining) {
        if (block.timestamp >= endTime) {
            return 0;
        }
        return endTime - block.timestamp;
    }

    // ============================================================================
    // AUCTION ID GENERATION
    // ============================================================================

    /**
     * @notice Generates a unique auction ID
     * @param nftContract NFT contract address
     * @param tokenId Token ID
     * @param seller Seller address
     * @param timestamp Timestamp for uniqueness
     * @return auctionId Generated auction ID
     */
    function generateAuctionId(address nftContract, uint256 tokenId, address seller, uint256 timestamp)
        internal
        pure
        returns (bytes32 auctionId)
    {
        return keccak256(abi.encodePacked(nftContract, tokenId, seller, timestamp, "AUCTION"));
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @notice Creates auction creation parameters struct
     * @param nftContract NFT contract address
     * @param tokenId Token ID
     * @param amount Amount (1 for ERC721)
     * @param startingPrice Starting price
     * @param reservePrice Reserve price
     * @param duration Auction duration
     * @param bidIncrement Minimum bid increment
     * @param extensionTime Extension time
     * @param seller Seller address
     * @param spender Spender address (auction contract)
     * @return params Auction creation parameters
     */
    function createAuctionParams(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 startingPrice,
        uint256 reservePrice,
        uint256 duration,
        uint256 bidIncrement,
        uint256 extensionTime,
        address seller,
        address spender
    ) internal pure returns (AuctionCreationParams memory params) {
        return AuctionCreationParams({
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            startingPrice: startingPrice,
            reservePrice: reservePrice,
            duration: duration,
            bidIncrement: bidIncrement,
            extensionTime: extensionTime,
            seller: seller,
            spender: spender
        });
    }

    /**
     * @notice Creates bid validation parameters struct
     * @param bidAmount Bid amount
     * @param currentHighestBid Current highest bid
     * @param minimumBidIncrement Minimum bid increment
     * @param reservePrice Reserve price
     * @param auctionEndTime Auction end time
     * @param hasReservePrice Whether auction has reserve price
     * @return params Bid validation parameters
     */
    function createBidValidationParams(
        uint256 bidAmount,
        uint256 currentHighestBid,
        uint256 minimumBidIncrement,
        uint256 reservePrice,
        uint256 auctionEndTime,
        bool hasReservePrice
    ) internal pure returns (BidValidationParams memory params) {
        return BidValidationParams({
            bidAmount: bidAmount,
            currentHighestBid: currentHighestBid,
            minimumBidIncrement: minimumBidIncrement,
            reservePrice: reservePrice,
            auctionEndTime: auctionEndTime,
            hasReservePrice: hasReservePrice
        });
    }
}
