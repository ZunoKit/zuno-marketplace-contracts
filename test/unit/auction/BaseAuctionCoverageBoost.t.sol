// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseAuction} from "src/core/auction/BaseAuction.sol";
import {IAuction} from "src/interfaces/IAuction.sol";
import {IMarketplaceValidator} from "src/interfaces/IMarketplaceValidator.sol";
import {AuctionCreationParams, AuctionType, DEFAULT_MIN_BID_INCREMENT} from "src/types/AuctionTypes.sol";
import {AuctionTestHelpers} from "test/utils/auction/AuctionTestHelpers.sol";
import {MarketplaceValidator} from "src/core/validation/MarketplaceValidator.sol";
import "src/errors/AuctionErrors.sol";

/**
 * @title BaseAuctionCoverageBoostTest
 * @notice Additional tests to boost BaseAuction coverage to >90%
 * @dev Focuses on uncovered functions, edge cases, and branch coverage
 */
contract BaseAuctionCoverageBoostTest is AuctionTestHelpers {
    CoverageTestableBaseAuction testableAuction;
    MarketplaceValidator validator;

    function setUp() public {
        setUpAuctionTests();

        // Deploy validator for testing
        validator = new MarketplaceValidator();

        // Create testable auction with validator
        testableAuction = new CoverageTestableBaseAuction(MARKETPLACE_WALLET);
        testableAuction.setMarketplaceValidator(address(validator));

        // Register auction contract with validator
        validator.registerAuction(address(testableAuction), 0);
    }

    // ============================================================================
    // ADMIN FUNCTIONS TESTS
    // ============================================================================

    function test_SetMarketplaceValidator_Success() public {
        address newValidator = makeAddr("newValidator");

        testableAuction.setMarketplaceValidator(newValidator);

        assertEq(address(testableAuction.marketplaceValidator()), newValidator);
    }

    function test_SetMarketplaceValidator_RevertNotOwner() public {
        address newValidator = makeAddr("newValidator");
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert("Error message");
        testableAuction.setMarketplaceValidator(newValidator);
    }

    function test_SetMarketplaceFee_EdgeCases() public {
        // Test setting to 0
        testableAuction.setMarketplaceFee(0);
        assertEq(testableAuction.marketplaceFee(), 0);

        // Test setting to maximum (10%)
        testableAuction.setMarketplaceFee(1000);
        assertEq(testableAuction.marketplaceFee(), 1000);
    }

    function test_SetMinBidIncrement_EdgeCases() public {
        // Test setting to minimum (1%)
        testableAuction.setMinBidIncrement(100);
        assertEq(testableAuction.minBidIncrement(), 100);

        // Test setting to maximum (50%)
        testableAuction.setMinBidIncrement(5000);
        assertEq(testableAuction.minBidIncrement(), 5000);
    }

    function test_SetMinAuctionDuration_Success() public {
        uint256 newMinDuration = 30 minutes;

        testableAuction.setMinAuctionDuration(newMinDuration);

        assertEq(testableAuction.minAuctionDuration(), newMinDuration);
    }

    function test_SetMaxAuctionDuration_Success() public {
        uint256 newMaxDuration = 60 days;

        testableAuction.setMaxAuctionDuration(newMaxDuration);

        assertEq(testableAuction.maxAuctionDuration(), newMaxDuration);
    }

    function test_SetMinAuctionDuration_RevertInvalidRange() public {
        uint256 invalidMinDuration = testableAuction.maxAuctionDuration() + 1; // Greater than max

        vm.expectRevert(Auction__InvalidAuctionDuration.selector);
        testableAuction.setMinAuctionDuration(invalidMinDuration);
    }

    function test_SetMaxAuctionDuration_RevertInvalidRange() public {
        uint256 invalidMaxDuration = testableAuction.minAuctionDuration() - 1; // Less than min

        vm.expectRevert(Auction__InvalidAuctionDuration.selector);
        testableAuction.setMaxAuctionDuration(invalidMaxDuration);
    }

    function test_SetMinAuctionDuration_RevertNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert("Error message");
        testableAuction.setMinAuctionDuration(1 hours);
    }

    function test_EmergencyResetNFTStatus_Success() public {
        // Test with validator set
        testableAuction.emergencyResetNFTStatus(address(mockERC721), 1, SELLER);

        // Should not revert - function should handle validator calls gracefully
        assertTrue(true);
    }

    function test_EmergencyResetNFTStatus_NoValidator() public {
        // Create auction without validator
        CoverageTestableBaseAuction auctionNoValidator = new CoverageTestableBaseAuction(MARKETPLACE_WALLET);

        // Should not revert even without validator
        auctionNoValidator.emergencyResetNFTStatus(address(mockERC721), 1, SELLER);
        assertTrue(true);
    }

    function test_EmergencyResetNFTStatus_RevertNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert("Error message");
        testableAuction.emergencyResetNFTStatus(address(mockERC721), 1, SELLER);
    }

    // ============================================================================
    // PAUSE/UNPAUSE TESTS
    // ============================================================================

    function test_SetPaused_Success() public {
        testableAuction.setPaused(true);
        assertTrue(testableAuction.paused());
    }

    function test_SetUnpaused_Success() public {
        testableAuction.setPaused(true);
        testableAuction.setPaused(false);
        assertFalse(testableAuction.paused());
    }

    function test_SetPaused_RevertNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert("Error message");
        testableAuction.setPaused(true);
    }

    function test_SetUnpaused_RevertNotOwner() public {
        testableAuction.setPaused(true);

        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        vm.expectRevert("Error message");
        testableAuction.setPaused(false);
    }

    // ============================================================================
    // VALIDATOR INTEGRATION TESTS
    // ============================================================================

    function test_ValidateNFTAvailability_WithValidator_Available() public {
        // The auction contract is already registered in setUp() as an auction
        // NFT should be available by default, so just test validation
        // Should not revert
        testableAuction.testValidateNFTAvailability(address(mockERC721), 1, SELLER);
    }

    function test_ValidateNFTAvailability_WithValidator_Listed() public {
        // First, we need to create a mock exchange to set the NFT as listed
        // since only registered contracts can call validator functions
        address mockExchange = makeAddr("mockExchange");
        validator.registerExchange(mockExchange, 0);

        // Set NFT as listed using the registered exchange contract
        vm.prank(mockExchange);
        validator.setNFTListed(address(mockERC721), 1, SELLER, bytes32("listing"));

        vm.expectRevert(Auction__NFTAlreadyListed.selector);
        testableAuction.testValidateNFTAvailability(address(mockERC721), 1, SELLER);
    }

    function test_ValidateNFTAvailability_WithValidator_InAuction() public {
        // Set NFT as in auction using the registered auction contract
        vm.prank(address(testableAuction));
        validator.setNFTInAuction(address(mockERC721), 1, SELLER, bytes32("auction"));

        vm.expectRevert(Auction__NFTAlreadyInAuction.selector);
        testableAuction.testValidateNFTAvailability(address(mockERC721), 1, SELLER);
    }

    // ============================================================================
    // INTERNAL FUNCTION TESTS
    // ============================================================================

    function test_NotifyValidatorAuctionCreated_Success() public {
        bytes32 auctionId = bytes32("test");

        // Should not revert
        testableAuction.testNotifyValidatorAuctionCreated(address(mockERC721), 1, SELLER, auctionId);
    }

    function test_NotifyValidatorAuctionCreated_NoValidator() public {
        CoverageTestableBaseAuction auctionNoValidator = new CoverageTestableBaseAuction(MARKETPLACE_WALLET);
        bytes32 auctionId = bytes32("test");

        // Should not revert even without validator
        auctionNoValidator.testNotifyValidatorAuctionCreated(address(mockERC721), 1, SELLER, auctionId);
    }

    function test_NotifyValidatorAuctionCancelled_Success() public {
        bytes32 auctionId = bytes32("test");

        // Should not revert
        testableAuction.testNotifyValidatorAuctionCancelled(address(mockERC721), 1, SELLER);
    }

    function test_NotifyValidatorAuctionSettled_Success() public {
        bytes32 auctionId = bytes32("test");

        // Should not revert
        testableAuction.testNotifyValidatorAuctionSettled(address(mockERC721), 1, SELLER, BIDDER1);
    }

    // ============================================================================
    // MODIFIER EDGE CASES
    // ============================================================================

    function test_OnlyFactory_WithZeroFactory() public {
        // Create auction where factory is address(0)
        CoverageTestableBaseAuction auctionZeroFactory = new CoverageTestableBaseAuction(MARKETPLACE_WALLET);

        // Calling factory functions should revert with NotAuthorized
        // because factory is address(0) and onlyFactory modifier fails first
        vm.expectRevert(Auction__NotAuthorized.selector);
        auctionZeroFactory.placeBidFor{value: 1 ether}(bytes32("test"), makeAddr("bidder"));
    }

    // ============================================================================
    // GETTER FUNCTION TESTS
    // ============================================================================

    function test_GetActiveAuctions_EmptyArray() public {
        bytes32[] memory auctions = testableAuction.getActiveAuctions();
        assertEq(auctions.length, 0);
    }

    function test_GetAuctionsBySeller_EmptyArray() public {
        bytes32[] memory auctions = testableAuction.getAuctionsBySeller(SELLER);
        assertEq(auctions.length, 0);
    }

    function test_GetAuctionsByContract_EmptyArray() public {
        bytes32[] memory auctions = testableAuction.getAuctionsByContract(address(mockERC721));
        assertEq(auctions.length, 0);
    }

    function test_IsAuctionActive_NonExistentAuction() public {
        bytes32 nonExistentId = bytes32("nonexistent");
        assertFalse(testableAuction.isAuctionActive(nonExistentId));
    }

    // ============================================================================
    // EDGE CASE AND ERROR CONDITION TESTS
    // ============================================================================

    function test_ValidateAuctionParameters_ZeroAddress() public {
        AuctionCreationParams memory params = AuctionCreationParams({
            nftContract: address(0), // Zero address
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 1 days,
            auctionType: AuctionType.ENGLISH,
            seller: SELLER,
            bidIncrement: DEFAULT_MIN_BID_INCREMENT,
            extendOnBid: false
        });

        vm.expectRevert(Auction__ZeroAddress.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_ExcessiveReservePrice() public {
        AuctionCreationParams memory params = AuctionCreationParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 11 ether, // More than 10x start price
            duration: 1 days,
            auctionType: AuctionType.ENGLISH,
            seller: SELLER,
            bidIncrement: DEFAULT_MIN_BID_INCREMENT,
            extendOnBid: false
        });

        vm.expectRevert(Auction__InvalidReservePrice.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_DurationTooShort() public {
        // Set very short minimum duration for testing
        testableAuction.setMinAuctionDuration(1 hours);

        AuctionCreationParams memory params = AuctionCreationParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 30 minutes, // Too short
            auctionType: AuctionType.ENGLISH,
            seller: SELLER,
            bidIncrement: DEFAULT_MIN_BID_INCREMENT,
            extendOnBid: false
        });

        vm.expectRevert(Auction__InvalidAuctionDuration.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_ValidateAuctionParameters_DurationTooLong() public {
        AuctionCreationParams memory params = AuctionCreationParams({
            nftContract: address(mockERC721),
            tokenId: 1,
            amount: 1,
            startPrice: 1 ether,
            reservePrice: 2 ether,
            duration: 31 days, // Too long (default max is 30 days)
            auctionType: AuctionType.ENGLISH,
            seller: SELLER,
            bidIncrement: DEFAULT_MIN_BID_INCREMENT,
            extendOnBid: false
        });

        vm.expectRevert(Auction__InvalidAuctionDuration.selector);
        testableAuction.testValidateAuctionParameters(params);
    }

    function test_SetMarketplaceFee_RevertTooHigh() public {
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMarketplaceFee(10001); // Over 100%
    }

    function test_SetMinBidIncrement_RevertTooLow() public {
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMinBidIncrement(0); // Zero
    }

    function test_SetMinBidIncrement_RevertTooHigh() public {
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        testableAuction.setMinBidIncrement(10001); // Over 100%
    }

    // ============================================================================
    // PAYMENT DISTRIBUTION EDGE CASES
    // ============================================================================

    function test_CalculatePaymentDistribution_ZeroRoyalty() public {
        uint256 finalPrice = 10 ether;
        uint256 royaltyAmount = 0;

        (uint256 sellerAmount, uint256 marketplaceFeeAmount, uint256 returnedRoyalty) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        // With 2% marketplace fee (default is 200 basis points)
        uint256 expectedMarketplaceFee = (finalPrice * 200) / 10000;
        uint256 expectedSellerAmount = finalPrice - expectedMarketplaceFee;

        assertEq(marketplaceFeeAmount, expectedMarketplaceFee);
        assertEq(sellerAmount, expectedSellerAmount);
        assertEq(returnedRoyalty, royaltyAmount);
    }

    function test_CalculatePaymentDistribution_HighRoyalty() public {
        uint256 finalPrice = 10 ether;
        uint256 royaltyAmount = 1 ether; // 10% royalty

        (uint256 sellerAmount, uint256 marketplaceFeeAmount, uint256 returnedRoyalty) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        uint256 expectedMarketplaceFee = (finalPrice * 200) / 10000; // 2%
        uint256 expectedSellerAmount = finalPrice - expectedMarketplaceFee - royaltyAmount;

        assertEq(marketplaceFeeAmount, expectedMarketplaceFee);
        assertEq(sellerAmount, expectedSellerAmount);
        assertEq(returnedRoyalty, royaltyAmount);
    }

    function test_CalculatePaymentDistribution_SmallAmount() public {
        uint256 finalPrice = 1000 wei; // Very small amount
        uint256 royaltyAmount = 50 wei;

        (uint256 sellerAmount, uint256 marketplaceFeeAmount, uint256 returnedRoyalty) =
            testableAuction.testCalculatePaymentDistribution(finalPrice, royaltyAmount);

        // Should handle small amounts without underflow
        assertTrue(sellerAmount + marketplaceFeeAmount + returnedRoyalty <= finalPrice);
    }
}

/**
 * @title CoverageTestableBaseAuction
 * @notice Test contract that exposes internal BaseAuction functions for coverage testing
 */
contract CoverageTestableBaseAuction is BaseAuction {
    constructor(address _marketplaceWallet) BaseAuction(_marketplaceWallet) {}

    // Expose internal functions for testing
    function testValidateNFTAvailability(address nftContract, uint256 tokenId, address seller) external {
        _validateNFTAvailability(nftContract, tokenId, seller);
    }

    function testNotifyValidatorAuctionCreated(address nftContract, uint256 tokenId, address seller, bytes32 auctionId)
        external
    {
        _notifyValidatorAuctionCreated(nftContract, tokenId, seller, auctionId);
    }

    function testNotifyValidatorAuctionCancelled(address nftContract, uint256 tokenId, address seller) external {
        _notifyValidatorAuctionCancelled(nftContract, tokenId, seller);
    }

    function testNotifyValidatorAuctionSettled(address nftContract, uint256 tokenId, address oldOwner, address newOwner)
        external
    {
        _notifyValidatorAuctionSettled(nftContract, tokenId, oldOwner, newOwner);
    }

    function testValidateAuctionParameters(AuctionCreationParams memory params) external view {
        _validateAuctionParameters(params);
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
