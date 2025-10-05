// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/common/Constants.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title ConstantsTest
 * @notice Comprehensive test suite for Constants library
 * @dev Tests all constants and helper functions to achieve >90% coverage
 */
contract ConstantsTest is Test {
    // ============================================================================
    // FEE CONSTANTS TESTS
    // ============================================================================

    function test_BPS_DENOMINATOR() public {
        assertEq(Constants.BPS_DENOMINATOR, 10000);
        // Verify it represents 100%
        assertEq(Constants.BPS_DENOMINATOR / 100, 100); // 1% = 100 BPS
    }

    function test_MAX_FEE_BPS() public {
        assertEq(Constants.MAX_FEE_BPS, 1000);
        // Verify it's 10% of total
        assertEq((Constants.MAX_FEE_BPS * 100) / Constants.BPS_DENOMINATOR, 10);
    }

    function test_DEFAULT_MAKER_FEE_BPS() public {
        assertEq(Constants.DEFAULT_MAKER_FEE_BPS, 250);
        // Verify it's 2.5%
        assertEq((Constants.DEFAULT_MAKER_FEE_BPS * 100) / Constants.BPS_DENOMINATOR, 2);
        // Verify it's within max fee
        assertLe(Constants.DEFAULT_MAKER_FEE_BPS, Constants.MAX_FEE_BPS);
    }

    function test_DEFAULT_TAKER_FEE_BPS() public {
        assertEq(Constants.DEFAULT_TAKER_FEE_BPS, 250);
        // Verify it's 2.5%
        assertEq((Constants.DEFAULT_TAKER_FEE_BPS * 100) / Constants.BPS_DENOMINATOR, 2);
        // Verify it's within max fee
        assertLe(Constants.DEFAULT_TAKER_FEE_BPS, Constants.MAX_FEE_BPS);
    }

    function test_MAX_ROYALTY_BPS() public {
        assertEq(Constants.MAX_ROYALTY_BPS, 1000);
        // Verify it's same as max fee
        assertEq(Constants.MAX_ROYALTY_BPS, Constants.MAX_FEE_BPS);
    }

    // ============================================================================
    // AUCTION CONSTANTS TESTS
    // ============================================================================

    function test_MIN_AUCTION_DURATION() public {
        assertEq(Constants.MIN_AUCTION_DURATION, 1 hours);
        assertEq(Constants.MIN_AUCTION_DURATION, 3600); // 1 hour in seconds
    }

    function test_MAX_AUCTION_DURATION() public {
        assertEq(Constants.MAX_AUCTION_DURATION, 30 days);
        assertEq(Constants.MAX_AUCTION_DURATION, 30 * 24 * 3600); // 30 days in seconds
        // Verify max is greater than min
        assertGt(Constants.MAX_AUCTION_DURATION, Constants.MIN_AUCTION_DURATION);
    }

    function test_DEFAULT_EXTENSION_TIME() public {
        assertEq(Constants.DEFAULT_EXTENSION_TIME, 15 minutes);
        assertEq(Constants.DEFAULT_EXTENSION_TIME, 15 * 60); // 15 minutes in seconds
    }

    function test_MIN_BID_INCREMENT_BPS() public {
        assertEq(Constants.MIN_BID_INCREMENT_BPS, 100);
        // Verify it's 1%
        assertEq((Constants.MIN_BID_INCREMENT_BPS * 100) / Constants.BPS_DENOMINATOR, 1);
    }

    function test_EXTENSION_THRESHOLD() public {
        assertEq(Constants.EXTENSION_THRESHOLD, 15 minutes);
        assertEq(Constants.EXTENSION_THRESHOLD, 15 * 60); // 15 minutes in seconds
    }

    // ============================================================================
    // LISTING CONSTANTS TESTS
    // ============================================================================

    function test_MIN_LISTING_DURATION() public {
        assertEq(Constants.MIN_LISTING_DURATION, 1 hours);
        assertEq(Constants.MIN_LISTING_DURATION, 3600); // 1 hour in seconds
    }

    function test_MAX_LISTING_DURATION() public {
        assertEq(Constants.MAX_LISTING_DURATION, 365 days);
        assertEq(Constants.MAX_LISTING_DURATION, 365 * 24 * 3600); // 1 year in seconds
        // Verify max is greater than min
        assertGt(Constants.MAX_LISTING_DURATION, Constants.MIN_LISTING_DURATION);
    }

    function test_DEFAULT_LISTING_DURATION() public {
        assertEq(Constants.DEFAULT_LISTING_DURATION, 7 days);
        assertEq(Constants.DEFAULT_LISTING_DURATION, 7 * 24 * 3600); // 7 days in seconds
        // Verify default is within min/max range
        assertGe(Constants.DEFAULT_LISTING_DURATION, Constants.MIN_LISTING_DURATION);
        assertLe(Constants.DEFAULT_LISTING_DURATION, Constants.MAX_LISTING_DURATION);
    }

    // ============================================================================
    // OFFER CONSTANTS TESTS
    // ============================================================================

    function test_MIN_OFFER_DURATION() public {
        assertEq(Constants.MIN_OFFER_DURATION, 1 hours);
        assertEq(Constants.MIN_OFFER_DURATION, 3600); // 1 hour in seconds
    }

    function test_MAX_OFFER_DURATION() public {
        assertEq(Constants.MAX_OFFER_DURATION, 30 days);
        assertEq(Constants.MAX_OFFER_DURATION, 30 * 24 * 3600); // 30 days in seconds
        // Verify max is greater than min
        assertGt(Constants.MAX_OFFER_DURATION, Constants.MIN_OFFER_DURATION);
    }

    function test_DEFAULT_OFFER_DURATION() public {
        assertEq(Constants.DEFAULT_OFFER_DURATION, 24 hours);
        assertEq(Constants.DEFAULT_OFFER_DURATION, 24 * 3600); // 24 hours in seconds
        // Verify default is within min/max range
        assertGe(Constants.DEFAULT_OFFER_DURATION, Constants.MIN_OFFER_DURATION);
        assertLe(Constants.DEFAULT_OFFER_DURATION, Constants.MAX_OFFER_DURATION);
    }

    // ============================================================================
    // VALIDATION CONSTANTS TESTS
    // ============================================================================

    function test_MIN_PRICE() public {
        assertEq(Constants.MIN_PRICE, 0.001 ether);
        assertEq(Constants.MIN_PRICE, 1000000000000000); // 0.001 ETH in wei
        assertGt(Constants.MIN_PRICE, 0); // Must be greater than zero
    }

    function test_MAX_BATCH_SIZE() public {
        assertEq(Constants.MAX_BATCH_SIZE, 50);
        assertGt(Constants.MAX_BATCH_SIZE, 0); // Must be greater than zero
        assertLe(Constants.MAX_BATCH_SIZE, 100); // Reasonable upper bound
    }

    function test_MAX_STRING_LENGTH() public {
        assertEq(Constants.MAX_STRING_LENGTH, 256);
        assertGt(Constants.MAX_STRING_LENGTH, 0); // Must be greater than zero
    }

    // ============================================================================
    // STATUS CONSTANTS TESTS
    // ============================================================================

    function test_STATUS_ACTIVE() public {
        assertEq(Constants.STATUS_ACTIVE, 1);
    }

    function test_STATUS_SOLD() public {
        assertEq(Constants.STATUS_SOLD, 2);
        assertGt(Constants.STATUS_SOLD, Constants.STATUS_ACTIVE);
    }

    function test_STATUS_CANCELLED() public {
        assertEq(Constants.STATUS_CANCELLED, 3);
        assertGt(Constants.STATUS_CANCELLED, Constants.STATUS_SOLD);
    }

    function test_STATUS_EXPIRED() public {
        assertEq(Constants.STATUS_EXPIRED, 4);
        assertGt(Constants.STATUS_EXPIRED, Constants.STATUS_CANCELLED);
    }

    function test_StatusConstants_AreUnique() public {
        // Verify all status constants are unique
        uint256[] memory statuses = new uint256[](4);
        statuses[0] = Constants.STATUS_ACTIVE;
        statuses[1] = Constants.STATUS_SOLD;
        statuses[2] = Constants.STATUS_CANCELLED;
        statuses[3] = Constants.STATUS_EXPIRED;

        for (uint256 i = 0; i < statuses.length; i++) {
            for (uint256 j = i + 1; j < statuses.length; j++) {
                assertNotEq(statuses[i], statuses[j], "Status constants must be unique");
            }
        }
    }

    // ============================================================================
    // ERC INTERFACE ID TESTS
    // ============================================================================

    function test_ERC721_INTERFACE_ID() public {
        assertEq(uint32(Constants.ERC721_INTERFACE_ID), uint32(0x80ac58cd));
        // Verify it's the correct ERC721 interface ID
        assertEq(uint32(Constants.ERC721_INTERFACE_ID), uint32(type(IERC721).interfaceId));
    }

    function test_ERC1155_INTERFACE_ID() public {
        assertEq(uint32(Constants.ERC1155_INTERFACE_ID), uint32(0xd9b67a26));
        // Verify it's the correct ERC1155 interface ID
        assertEq(uint32(Constants.ERC1155_INTERFACE_ID), uint32(type(IERC1155).interfaceId));
    }

    function test_ERC2981_INTERFACE_ID() public {
        assertEq(uint32(Constants.ERC2981_INTERFACE_ID), uint32(0x2a55205a));
        // Verify it's the correct ERC2981 interface ID
        assertEq(uint32(Constants.ERC2981_INTERFACE_ID), uint32(type(IERC2981).interfaceId));
    }

    function test_InterfaceIds_AreUnique() public {
        // Verify all interface IDs are unique
        bytes4[] memory interfaceIds = new bytes4[](3);
        interfaceIds[0] = Constants.ERC721_INTERFACE_ID;
        interfaceIds[1] = Constants.ERC1155_INTERFACE_ID;
        interfaceIds[2] = Constants.ERC2981_INTERFACE_ID;

        for (uint256 i = 0; i < interfaceIds.length; i++) {
            for (uint256 j = i + 1; j < interfaceIds.length; j++) {
                assertNotEq(uint32(interfaceIds[i]), uint32(interfaceIds[j]), "Interface IDs must be unique");
            }
        }
    }

    // ============================================================================
    // HELPER FUNCTION TESTS
    // ============================================================================

    function test_IsValidPrice_ValidPrices() public {
        assertTrue(Constants.isValidPrice(Constants.MIN_PRICE));
        assertTrue(Constants.isValidPrice(1 ether));
        assertTrue(Constants.isValidPrice(100 ether));
        assertTrue(Constants.isValidPrice(Constants.MIN_PRICE + 1));
    }

    function test_IsValidPrice_InvalidPrices() public {
        assertFalse(Constants.isValidPrice(0));
        assertFalse(Constants.isValidPrice(Constants.MIN_PRICE - 1));
    }

    function test_IsValidListingDuration_ValidDurations() public {
        assertTrue(Constants.isValidListingDuration(Constants.MIN_LISTING_DURATION));
        assertTrue(Constants.isValidListingDuration(Constants.DEFAULT_LISTING_DURATION));
        assertTrue(Constants.isValidListingDuration(Constants.MAX_LISTING_DURATION));
        assertTrue(Constants.isValidListingDuration(7 days));
    }

    function test_IsValidListingDuration_InvalidDurations() public {
        assertFalse(Constants.isValidListingDuration(0));
        assertFalse(Constants.isValidListingDuration(Constants.MIN_LISTING_DURATION - 1));
        assertFalse(Constants.isValidListingDuration(Constants.MAX_LISTING_DURATION + 1));
    }

    function test_IsValidAuctionDuration_ValidDurations() public {
        assertTrue(Constants.isValidAuctionDuration(Constants.MIN_AUCTION_DURATION));
        assertTrue(Constants.isValidAuctionDuration(Constants.MAX_AUCTION_DURATION));
        assertTrue(Constants.isValidAuctionDuration(3 days));
    }

    function test_IsValidAuctionDuration_InvalidDurations() public {
        assertFalse(Constants.isValidAuctionDuration(0));
        assertFalse(Constants.isValidAuctionDuration(Constants.MIN_AUCTION_DURATION - 1));
        assertFalse(Constants.isValidAuctionDuration(Constants.MAX_AUCTION_DURATION + 1));
    }

    function test_IsValidOfferDuration_ValidDurations() public {
        assertTrue(Constants.isValidOfferDuration(Constants.MIN_OFFER_DURATION));
        assertTrue(Constants.isValidOfferDuration(Constants.DEFAULT_OFFER_DURATION));
        assertTrue(Constants.isValidOfferDuration(Constants.MAX_OFFER_DURATION));
        assertTrue(Constants.isValidOfferDuration(12 hours));
    }

    function test_IsValidOfferDuration_InvalidDurations() public {
        assertFalse(Constants.isValidOfferDuration(0));
        assertFalse(Constants.isValidOfferDuration(Constants.MIN_OFFER_DURATION - 1));
        assertFalse(Constants.isValidOfferDuration(Constants.MAX_OFFER_DURATION + 1));
    }

    function test_IsValidFee_ValidFees() public {
        assertTrue(Constants.isValidFee(0));
        assertTrue(Constants.isValidFee(Constants.DEFAULT_MAKER_FEE_BPS));
        assertTrue(Constants.isValidFee(Constants.DEFAULT_TAKER_FEE_BPS));
        assertTrue(Constants.isValidFee(Constants.MAX_FEE_BPS));
    }

    function test_IsValidFee_InvalidFees() public {
        assertFalse(Constants.isValidFee(Constants.MAX_FEE_BPS + 1));
        assertFalse(Constants.isValidFee(type(uint256).max));
    }

    function test_IsValidBatchSize_ValidSizes() public {
        assertTrue(Constants.isValidBatchSize(1));
        assertTrue(Constants.isValidBatchSize(25));
        assertTrue(Constants.isValidBatchSize(Constants.MAX_BATCH_SIZE));
    }

    function test_IsValidBatchSize_InvalidSizes() public {
        assertFalse(Constants.isValidBatchSize(0));
        assertFalse(Constants.isValidBatchSize(Constants.MAX_BATCH_SIZE + 1));
        assertFalse(Constants.isValidBatchSize(type(uint256).max));
    }

    // ============================================================================
    // FUZZ TESTS
    // ============================================================================

    function testFuzz_IsValidPrice(uint256 price) public {
        bool expected = price >= Constants.MIN_PRICE;
        assertEq(Constants.isValidPrice(price), expected);
    }

    function testFuzz_IsValidFee(uint256 fee) public {
        bool expected = fee <= Constants.MAX_FEE_BPS;
        assertEq(Constants.isValidFee(fee), expected);
    }

    function testFuzz_IsValidBatchSize(uint256 size) public {
        bool expected = size > 0 && size <= Constants.MAX_BATCH_SIZE;
        assertEq(Constants.isValidBatchSize(size), expected);
    }

    function testFuzz_IsValidListingDuration(uint256 duration) public {
        bool expected = duration >= Constants.MIN_LISTING_DURATION && duration <= Constants.MAX_LISTING_DURATION;
        assertEq(Constants.isValidListingDuration(duration), expected);
    }

    function testFuzz_IsValidAuctionDuration(uint256 duration) public {
        bool expected = duration >= Constants.MIN_AUCTION_DURATION && duration <= Constants.MAX_AUCTION_DURATION;
        assertEq(Constants.isValidAuctionDuration(duration), expected);
    }

    function testFuzz_IsValidOfferDuration(uint256 duration) public {
        bool expected = duration >= Constants.MIN_OFFER_DURATION && duration <= Constants.MAX_OFFER_DURATION;
        assertEq(Constants.isValidOfferDuration(duration), expected);
    }

    // ============================================================================
    // INTEGRATION TESTS
    // ============================================================================

    function test_ConstantsConsistency() public {
        // Verify fee constants are consistent
        assertLe(Constants.DEFAULT_MAKER_FEE_BPS, Constants.MAX_FEE_BPS);
        assertLe(Constants.DEFAULT_TAKER_FEE_BPS, Constants.MAX_FEE_BPS);

        // Verify duration constants are consistent
        assertLe(Constants.MIN_LISTING_DURATION, Constants.DEFAULT_LISTING_DURATION);
        assertLe(Constants.DEFAULT_LISTING_DURATION, Constants.MAX_LISTING_DURATION);

        assertLe(Constants.MIN_AUCTION_DURATION, Constants.MAX_AUCTION_DURATION);

        assertLe(Constants.MIN_OFFER_DURATION, Constants.DEFAULT_OFFER_DURATION);
        assertLe(Constants.DEFAULT_OFFER_DURATION, Constants.MAX_OFFER_DURATION);

        // Verify bid increment is reasonable
        assertLe(Constants.MIN_BID_INCREMENT_BPS, Constants.MAX_FEE_BPS);
    }

    function test_PercentageCalculations() public {
        // Test percentage calculations using constants
        uint256 salePrice = 1 ether;

        uint256 makerFee = (salePrice * Constants.DEFAULT_MAKER_FEE_BPS) / Constants.BPS_DENOMINATOR;
        uint256 takerFee = (salePrice * Constants.DEFAULT_TAKER_FEE_BPS) / Constants.BPS_DENOMINATOR;

        assertEq(makerFee, 0.025 ether); // 2.5%
        assertEq(takerFee, 0.025 ether); // 2.5%

        // Verify total fees don't exceed reasonable limits
        uint256 totalFees = makerFee + takerFee;
        assertLe(totalFees, salePrice / 10); // Less than 10% total
    }
}

// Import required interfaces for testing
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
