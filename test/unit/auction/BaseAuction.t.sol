// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseAuction} from "src/core/auction/BaseAuction.sol";
import {IAuction} from "src/interfaces/IAuction.sol";
import {AuctionTestHelpers} from "../../utils/auction/AuctionTestHelpers.sol";
import "src/errors/AuctionErrors.sol";

/**
 * @title BaseAuctionTest
 * @notice Unit tests for BaseAuction contract functionality
 * @dev Tests internal functions and edge cases not covered by child contracts
 */
contract BaseAuctionTest is AuctionTestHelpers {
    // Test contract to expose internal functions
    TestableBaseAuction testableAuction;

    function setUp() public {
        setUpAuctionTests();
        testableAuction = new TestableBaseAuction(MARKETPLACE_WALLET);
    }

    // ============================================================================
    // AUCTION PARAMETER VALIDATION TESTS
    // ============================================================================

    function test_ValidateAuctionParameters_Success() public {
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 1 days,
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        // Should not revert
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_RevertZeroAddress() public {
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(0), // Invalid
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 1 days,
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        vm.expectRevert(Auction__ZeroAddress.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_RevertZeroStartPrice() public {
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 0, // Invalid
            reservePrice: 2 ether,
            duration: 1 days,
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        vm.expectRevert(Auction__InvalidStartPrice.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_RevertZeroAmount() public {
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 0, // Invalid
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 1 days,
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_RevertInvalidDuration() public {
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 30 minutes, // Too short
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        vm.expectRevert(Auction__InvalidAuctionDuration.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_RevertExcessiveReservePrice() public {
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 15 ether, // More than 10x start price
            duration: 1 days,
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        vm.expectRevert(Auction__InvalidReservePrice.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    // ============================================================================
    // AUCTION ID GENERATION TESTS
    // ============================================================================

    function test_GenerateAuctionId_Unique() public {
        bytes32 id1 = testableAuction.testGenerateAuctionId(address(mockERC721), 1, SELLER, block.timestamp);

        vm.warp(block.timestamp + 1);

        bytes32 id2 = testableAuction.testGenerateAuctionId(address(mockERC721), 1, SELLER, block.timestamp);

        assertTrue(id1 != id2);
    }

    // ============================================================================
    // PAYMENT CALCULATION TESTS
    // ============================================================================

    function test_CalculatePaymentDistribution_Success() public {
        uint256 finalPrice = 10 ether;
        uint256 royaltyAmount = 1 ether; // 10%

        (uint256 sellerAmount, uint256 marketplaceFeeAmount, uint256 royaltyAmountCalculated) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        uint256 expectedMarketplaceFee = (finalPrice * 200) / 10000; // 2%
        uint256 expectedSellerAmount = finalPrice - expectedMarketplaceFee - royaltyAmount;

        assertEq(sellerAmount, expectedSellerAmount);
        assertEq(marketplaceFeeAmount, expectedMarketplaceFee);
        assertEq(royaltyAmountCalculated, royaltyAmount);
    }

    function test_CalculatePaymentDistribution_ZeroRoyalty() public {
        uint256 finalPrice = 10 ether;
        uint256 royaltyAmount = 0;

        (uint256 sellerAmount, uint256 marketplaceFeeAmount, uint256 royaltyAmountCalculated) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        uint256 expectedMarketplaceFee = (finalPrice * 200) / 10000; // 2%
        uint256 expectedSellerAmount = finalPrice - expectedMarketplaceFee;

        assertEq(sellerAmount, expectedSellerAmount);
        assertEq(marketplaceFeeAmount, expectedMarketplaceFee);
        assertEq(royaltyAmountCalculated, 0);
    }

    // ============================================================================
    // AUCTION STATUS TESTS
    // ============================================================================

    function test_IsAuctionActive_True() public {
        bytes32 auctionId = createBasicEnglishAuction(1);
        // Use the auction factory to check if auction is active (since auction was created through factory)
        assertTrue(auctionFactory.isAuctionActive(auctionId));
    }

    function test_IsAuctionActive_False_Ended() public {
        bytes32 auctionId = createBasicEnglishAuction(1);

        // Fast forward past end time
        fastForwardToAuctionEnd(auctionId);

        // Use the English auction contract to check if auction is active
        assertFalse(englishAuction.isAuctionActive(auctionId));
    }

    // ============================================================================
    // CONFIGURATION TESTS
    // ============================================================================

    // ============================================================================
    // CONFIGURATION TESTS
    // ============================================================================

    function test_SetMarketplaceFee_Success() public {
        uint256 newFee = 300; // 3%

        vm.prank(testableAuction.owner());
        testableAuction.setMarketplaceFee(newFee);

        assertEq(testableAuction.marketplaceFee(), newFee);
    }

    function test_SetMarketplaceFee_RevertIfTooHigh() public {
        uint256 invalidFee = 10001; // > 100%

        vm.prank(testableAuction.owner());
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMarketplaceFee(invalidFee);
    }

    function test_SetMinBidIncrement_Success() public {
        uint256 newIncrement = 1000; // 10%

        vm.prank(testableAuction.owner());
        testableAuction.setMinBidIncrement(newIncrement);

        assertEq(testableAuction.minBidIncrement(), newIncrement);
    }

    // ============================================================================
    // ADDITIONAL EDGE CASE TESTS FOR BETTER COVERAGE
    // ============================================================================

    function test_ValidateAuctionParameters_EdgeCases() public {
        // Test minimum valid duration (1 hour)
        BaseAuction.AuctionParams memory params = BaseAuction.AuctionParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 1 hours, // Minimum valid
            auctionType: IAuction.AuctionType.ENGLISH,
            seller: SELLER
        });

        // Should not revert
        testableAuction.testValidateAuctionParameters(params);

        // Test maximum valid reserve price (10x start price)
        params.reservePrice = 10 ether; // Exactly 10x
        testableAuction.testValidateAuctionParameters(params);

        // Test with zero NFT contract address - should revert
        params.nftContract = address(0);
        vm.expectRevert(Auction__ZeroAddress.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_CalculatePaymentDistribution_EdgeCases() public {
        // Test with very small amounts
        uint256 finalPrice = 1 wei;
        uint256 royaltyAmount = 0;

        (uint256 sellerAmount, uint256 marketplaceFeeAmount, uint256 royaltyAmountCalculated) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        // With 2% marketplace fee, 1 wei should result in 0 fee due to rounding
        assertEq(marketplaceFeeAmount, 0);
        assertEq(sellerAmount, 1 wei);
        assertEq(royaltyAmountCalculated, 0);

        // Test with high royalty amount
        finalPrice = 10 ether;
        royaltyAmount = 5 ether; // 50%

        (sellerAmount, marketplaceFeeAmount, royaltyAmountCalculated) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        uint256 expectedMarketplaceFee = (finalPrice * 200) / 10000; // 2%
        uint256 expectedSellerAmount = finalPrice - expectedMarketplaceFee - royaltyAmount;

        assertEq(sellerAmount, expectedSellerAmount);
        assertEq(marketplaceFeeAmount, expectedMarketplaceFee);
        assertEq(royaltyAmountCalculated, royaltyAmount);
    }

    function test_GenerateAuctionId_DifferentInputs() public {
        // Test with different contracts
        bytes32 id1 = testableAuction.testGenerateAuctionId(address(mockERC721), 1, SELLER, block.timestamp);
        bytes32 id2 = testableAuction.testGenerateAuctionId(address(mockERC1155), 1, SELLER, block.timestamp);
        assertTrue(id1 != id2, "Different contracts should generate different IDs");

        // Test with different token IDs
        id1 = testableAuction.testGenerateAuctionId(address(mockERC721), 1, SELLER, block.timestamp);
        id2 = testableAuction.testGenerateAuctionId(address(mockERC721), 2, SELLER, block.timestamp);
        assertTrue(id1 != id2, "Different token IDs should generate different IDs");

        // Test with different sellers
        id1 = testableAuction.testGenerateAuctionId(address(mockERC721), 1, SELLER, block.timestamp);
        id2 = testableAuction.testGenerateAuctionId(address(mockERC721), 1, BIDDER1, block.timestamp);
        assertTrue(id1 != id2, "Different sellers should generate different IDs");
    }

    function test_SetMarketplaceFee_BoundaryValues() public {
        vm.startPrank(testableAuction.owner());

        // Test minimum fee (0%)
        testableAuction.setMarketplaceFee(0);
        assertEq(testableAuction.marketplaceFee(), 0);

        // Test maximum valid fee (100%)
        testableAuction.setMarketplaceFee(10000);
        assertEq(testableAuction.marketplaceFee(), 10000);

        // Test just over maximum (should revert)
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMarketplaceFee(10001);

        vm.stopPrank();
    }

    function test_SetMinBidIncrement_BoundaryValues() public {
        vm.startPrank(testableAuction.owner());

        // Test minimum valid increment (1 basis point)
        testableAuction.setMinBidIncrement(1);
        assertEq(testableAuction.minBidIncrement(), 1);

        // Test high increment (50%)
        testableAuction.setMinBidIncrement(5000);
        assertEq(testableAuction.minBidIncrement(), 5000);

        // Test maximum valid increment (100%)
        testableAuction.setMinBidIncrement(10000);
        assertEq(testableAuction.minBidIncrement(), 10000);

        // Test zero increment (should revert)
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMinBidIncrement(0);

        // Test over maximum (should revert)
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMinBidIncrement(10001);

        vm.stopPrank();
    }

    function test_AccessControl() public {
        address nonOwner = makeAddr("nonOwner");

        // Test that non-owner cannot set marketplace fee
        vm.prank(nonOwner);
        vm.expectRevert();
        testableAuction.setMarketplaceFee(300);

        // Test that non-owner cannot set min bid increment
        vm.prank(nonOwner);
        vm.expectRevert();
        testableAuction.setMinBidIncrement(300);
    }
}

/**
 * @title TestableBaseAuction
 * @notice Test contract that exposes internal BaseAuction functions
 */
contract TestableBaseAuction is BaseAuction {
    constructor(address _marketplaceWallet) BaseAuction(_marketplaceWallet) {}

    function testValidateAuctionParameters(AuctionParams memory params) external view {
        _validateAuctionParameters(params);
    }

    function testGenerateAuctionId(address nftContract, uint256 tokenId, address seller, uint256 timestamp)
        external
        pure
        returns (bytes32)
    {
        return _generateAuctionId(nftContract, tokenId, seller, timestamp);
    }

    function testCalculatePaymentDistribution(uint256 finalPrice, uint256 royaltyAmount)
        external
        view
        returns (uint256, uint256, uint256)
    {
        uint256 marketplaceFeeAmount = (finalPrice * marketplaceFee) / BPS_DENOMINATOR;
        uint256 sellerAmount = finalPrice - marketplaceFeeAmount - royaltyAmount;
        return (sellerAmount, marketplaceFeeAmount, royaltyAmount);
    }

    // Required implementations for abstract functions
    function placeBid(bytes32) external payable override {}
    function buyNow(bytes32) external payable override {}
    function withdrawBid(bytes32) external override {}
    function settleAuction(bytes32) external override {}

    function getCurrentPrice(bytes32) external view override returns (uint256) {
        return 0;
    }

    function getMinNextBid(bytes32) external view returns (uint256) {
        return 0;
    }
}
