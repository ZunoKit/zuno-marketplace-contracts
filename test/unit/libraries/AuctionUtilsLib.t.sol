// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/libraries/AuctionUtilsLib.sol";
import "src/libraries/NFTValidationLib.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";

/**
 * @title AuctionUtilsLibTest
 * @notice Comprehensive tests for AuctionUtilsLib library functions
 */
contract AuctionUtilsLibTest is Test {
    using AuctionUtilsLib for *;

    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public seller = address(0x1);
    address public spender = address(0x2);
    uint256 public tokenId = 1;
    uint256 public amount = 1;

    function setUp() public {
        mockERC721 = new MockERC721("Test NFT", "TEST");
        mockERC1155 = new MockERC1155("Test 1155", "T1155");

        // Mint tokens to seller
        mockERC721.mint(seller, tokenId);
        mockERC1155.mint(seller, tokenId, 10);

        // Set approvals
        vm.startPrank(seller);
        mockERC721.setApprovalForAll(spender, true);
        mockERC1155.setApprovalForAll(spender, true);
        vm.stopPrank();
    }

    // ============================================================================
    // AUCTION CREATION VALIDATION TESTS
    // ============================================================================

    function testValidateAuctionCreation_Success() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC721),
            tokenId,
            amount,
            1 ether, // startingPrice
            2 ether, // reservePrice
            1 days, // duration
            0.1 ether, // bidIncrement
            10 minutes, // extensionTime
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateAuctionCreation(params);

        assertTrue(result.isValid);
        assertEq(result.errorMessage, "");
    }

    function testValidateAuctionCreation_InvalidDuration() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC721),
            tokenId,
            amount,
            1 ether,
            2 ether,
            0, // Invalid duration (zero)
            0.1 ether,
            10 minutes,
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateAuctionCreation(params);

        assertFalse(result.isValid);
        assertTrue(bytes(result.errorMessage).length > 0);
    }

    function testValidateAuctionCreation_InvalidStartingPrice() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC721),
            tokenId,
            amount,
            0, // Invalid starting price
            2 ether,
            1 days,
            0.1 ether,
            10 minutes,
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateAuctionCreation(params);

        assertFalse(result.isValid);
        assertTrue(bytes(result.errorMessage).length > 0);
    }

    function testValidateAuctionCreation_InvalidReservePrice() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC721),
            tokenId,
            amount,
            2 ether,
            1 ether, // Reserve price lower than starting price
            1 days,
            0.1 ether,
            10 minutes,
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateAuctionCreation(params);

        assertFalse(result.isValid);
        assertTrue(bytes(result.errorMessage).length > 0);
    }

    function testValidateAuctionCreation_InvalidBidIncrement() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC721),
            tokenId,
            amount,
            1 ether,
            2 ether,
            1 days,
            0, // Invalid bid increment
            10 minutes,
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateAuctionCreation(params);

        assertFalse(result.isValid);
        assertTrue(bytes(result.errorMessage).length > 0);
    }

    function testValidateAuctionCreationForStandard_ERC721() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC721),
            tokenId,
            1, // Amount must be 1 for ERC721
            1 ether,
            2 ether,
            1 days,
            0.1 ether,
            10 minutes,
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result =
            AuctionUtilsLib.validateAuctionCreationForStandard(params, NFTValidationLib.NFTStandard.ERC721);

        assertTrue(result.isValid);
    }

    function testValidateAuctionCreationForStandard_ERC1155() public {
        AuctionUtilsLib.AuctionCreationParams memory params = AuctionUtilsLib.createAuctionParams(
            address(mockERC1155),
            tokenId,
            5, // Amount can be > 1 for ERC1155
            1 ether,
            2 ether,
            1 days,
            0.1 ether,
            10 minutes,
            seller,
            spender
        );

        AuctionUtilsLib.ValidationResult memory result =
            AuctionUtilsLib.validateAuctionCreationForStandard(params, NFTValidationLib.NFTStandard.ERC1155);

        assertTrue(result.isValid);
    }

    // ============================================================================
    // BID VALIDATION TESTS
    // ============================================================================

    function testValidateBid_Success() public {
        AuctionUtilsLib.BidValidationParams memory params = AuctionUtilsLib.createBidValidationParams(
            1.5 ether, // bidAmount
            1 ether, // currentHighestBid
            0.1 ether, // minimumBidIncrement
            0.5 ether, // reservePrice
            block.timestamp + 1 hours, // auctionEndTime
            true // hasReservePrice
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateBid(params);

        assertTrue(result.isValid);
        assertEq(result.errorMessage, "");
    }

    function testValidateBid_AuctionEnded() public {
        AuctionUtilsLib.BidValidationParams memory params = AuctionUtilsLib.createBidValidationParams(
            1.5 ether,
            1 ether,
            0.1 ether,
            0.5 ether,
            block.timestamp - 1, // Auction already ended
            true
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateBid(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Auction has ended");
    }

    function testValidateBid_BidTooLow() public {
        AuctionUtilsLib.BidValidationParams memory params = AuctionUtilsLib.createBidValidationParams(
            1.05 ether, // Too low compared to current + increment
            1 ether,
            0.1 ether,
            0.5 ether,
            block.timestamp + 1 hours,
            true
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateBid(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Bid too low");
    }

    function testValidateBid_BelowReservePrice() public {
        AuctionUtilsLib.BidValidationParams memory params = AuctionUtilsLib.createBidValidationParams(
            1.5 ether,
            1 ether,
            0.1 ether,
            2 ether, // Reserve price higher than bid
            block.timestamp + 1 hours,
            true
        );

        AuctionUtilsLib.ValidationResult memory result = AuctionUtilsLib.validateBid(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Bid below reserve price");
    }

    function testCalculateMinimumBid_WithReservePrice() public {
        uint256 minimumBid = AuctionUtilsLib.calculateMinimumBid(
            1 ether, // currentHighestBid
            0.1 ether, // bidIncrement
            2 ether // reservePrice
        );

        assertEq(minimumBid, 2 ether); // Reserve price is higher
    }

    function testCalculateMinimumBid_WithoutReservePrice() public {
        uint256 minimumBid = AuctionUtilsLib.calculateMinimumBid(
            1 ether, // currentHighestBid
            0.1 ether, // bidIncrement
            0.5 ether // reservePrice lower than increment bid
        );

        assertEq(minimumBid, 1.1 ether); // Increment bid is higher
    }

    // ============================================================================
    // TIME CALCULATION TESTS
    // ============================================================================

    function testCalculateAuctionExtension() public {
        uint256 currentEndTime = block.timestamp + 1 hours;
        uint256 extensionTime = 10 minutes;
        uint256 extensionThreshold = 15 minutes;

        AuctionUtilsLib.TimeCalculation memory timeCalc =
            AuctionUtilsLib.calculateAuctionExtension(currentEndTime, extensionTime, extensionThreshold);

        assertEq(timeCalc.endTime, currentEndTime);
        assertEq(timeCalc.extensionTime, extensionTime);
        assertFalse(timeCalc.needsExtension); // More than 15 minutes remaining
        assertEq(timeCalc.newEndTime, currentEndTime);
    }

    function testCalculateAuctionExtension_WithExtension() public {
        uint256 currentEndTime = block.timestamp + 10 minutes; // Within threshold
        uint256 extensionTime = 10 minutes;
        uint256 extensionThreshold = 15 minutes;

        AuctionUtilsLib.TimeCalculation memory timeCalc =
            AuctionUtilsLib.calculateAuctionExtension(currentEndTime, extensionTime, extensionThreshold);

        assertEq(timeCalc.endTime, currentEndTime);
        assertEq(timeCalc.extensionTime, extensionTime);
        assertTrue(timeCalc.needsExtension); // Within 15 minutes threshold
        assertEq(timeCalc.newEndTime, currentEndTime + extensionTime);
    }

    function testIsAuctionActive() public {
        uint256 futureTime = block.timestamp + 1 hours;
        uint256 pastTime = block.timestamp > 1 hours ? block.timestamp - 1 hours : 0;

        assertTrue(AuctionUtilsLib.isAuctionActive(futureTime));
        assertFalse(AuctionUtilsLib.isAuctionActive(pastTime));
    }

    function testGetTimeRemaining() public {
        uint256 futureTime = block.timestamp + 1 hours;
        uint256 pastTime = block.timestamp > 1 hours ? block.timestamp - 1 hours : 0;

        assertEq(AuctionUtilsLib.getTimeRemaining(futureTime), 1 hours);
        assertEq(AuctionUtilsLib.getTimeRemaining(pastTime), 0);
    }

    // ============================================================================
    // AUCTION ID GENERATION TESTS
    // ============================================================================

    function testGenerateAuctionId() public {
        bytes32 auctionId1 = AuctionUtilsLib.generateAuctionId(address(mockERC721), tokenId, seller, block.timestamp);

        bytes32 auctionId2 =
            AuctionUtilsLib.generateAuctionId(address(mockERC721), tokenId, seller, block.timestamp + 1);

        assertTrue(auctionId1 != bytes32(0));
        assertTrue(auctionId2 != bytes32(0));
        assertTrue(auctionId1 != auctionId2); // Different timestamps should produce different IDs
    }

    function testGenerateAuctionId_Deterministic() public {
        bytes32 auctionId1 = AuctionUtilsLib.generateAuctionId(address(mockERC721), tokenId, seller, 12345);

        bytes32 auctionId2 = AuctionUtilsLib.generateAuctionId(address(mockERC721), tokenId, seller, 12345);

        assertEq(auctionId1, auctionId2); // Same parameters should produce same ID
    }
}
