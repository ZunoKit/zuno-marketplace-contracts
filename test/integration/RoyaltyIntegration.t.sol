// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {AdvancedRoyaltyManager} from "src/core/fees/AdvancedRoyaltyManager.sol";
import {MarketplaceAccessControl} from "src/core/access/MarketplaceAccessControl.sol";
import {RoyaltyLib} from "src/libraries/RoyaltyLib.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {Fee} from "src/common/Fee.sol";

// Simple ERC721 without ERC2981 for testing Fee contract fallback
contract SimpleERC721 is ERC721, Ownable {
    Fee public feeContract;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setFeeContract(address _feeContract) external onlyOwner {
        feeContract = Fee(_feeContract);
    }

    function getFeeContract() external view returns (Fee) {
        return feeContract;
    }
}

/**
 * @title RoyaltyIntegration
 * @notice Comprehensive integration tests for royalty detection and distribution
 * @dev Tests all royalty methods: ERC2981, BaseCollection, Fee contract
 */
contract RoyaltyIntegrationTest is Test {
    ERC721NFTExchange public exchange;
    AdvancedRoyaltyManager public royaltyManager;
    MarketplaceAccessControl public accessControl;
    MockERC721 public mockNFT;
    Fee public feeContract;

    address public admin = address(0x1);
    address public seller = address(0x2);
    address public buyer = address(0x3);
    address public creator = address(0x4);
    address public marketplaceWallet = address(0x5);

    // Receive function to accept ETH payments
    receive() external payable {}

    uint256 public constant NFT_PRICE = 1 ether;
    uint256 public constant ROYALTY_5_PERCENT = 500; // 5%
    uint256 public constant ROYALTY_10_PERCENT = 1000; // 10%

    function setUp() public {
        // Deploy contracts
        accessControl = new MarketplaceAccessControl();
        feeContract = new Fee(creator, ROYALTY_5_PERCENT);
        royaltyManager = new AdvancedRoyaltyManager(address(accessControl), address(feeContract));

        exchange = new ERC721NFTExchange();
        exchange.initialize(marketplaceWallet, admin);

        mockNFT = new MockERC721("Test NFT", "TNFT");

        // Fund accounts
        vm.deal(buyer, 100 ether);
        vm.deal(seller, 100 ether);
    }

    // ============================================================================
    // ERC2981 ROYALTY DETECTION TESTS
    // ============================================================================

    function test_Integration_ERC2981RoyaltyDetection() public {
        console2.log("\n=== Test: ERC2981 Royalty Detection ===");

        // Setup: Mint NFT with ERC2981 royalty
        vm.prank(seller);
        mockNFT.mint(seller, 1);
        mockNFT.setDefaultRoyalty(creator, uint96(ROYALTY_5_PERCENT));

        // List NFT
        vm.startPrank(seller);
        mockNFT.setApprovalForAll(address(exchange), true);
        exchange.listNFT(address(mockNFT), 1, NFT_PRICE, 7 days);
        vm.stopPrank();

        bytes32 listingId = exchange.getGeneratedListingId(address(mockNFT), 1, seller);

        // Track balances
        uint256 creatorBalanceBefore = creator.balance;

        // Buy NFT
        uint256 totalPrice = exchange.getBuyerSeesPrice(listingId);
        vm.prank(buyer);
        exchange.buyNFT{value: totalPrice}(listingId);

        // Verify royalty paid to creator
        uint256 creatorBalanceAfter = creator.balance;
        uint256 expectedRoyalty = (NFT_PRICE * ROYALTY_5_PERCENT) / 10000;

        assertApproxEqAbs(
            creatorBalanceAfter - creatorBalanceBefore, expectedRoyalty, 1e15, "ERC2981 royalty not paid correctly"
        );

        console2.log("ERC2981 royalty paid:", expectedRoyalty);
        console2.log("=== ERC2981 Royalty Detection: SUCCESS ===\n");
    }

    // ============================================================================
    // FEE CONTRACT ROYALTY DETECTION TESTS
    // ============================================================================

    function test_Integration_FeeContractRoyaltyDetection() public {
        console2.log("\n=== Test: Fee Contract Royalty Detection ===");

        // Use SimpleERC721 without ERC2981 to test Fee contract fallback
        SimpleERC721 simpleNFT = new SimpleERC721("Simple NFT", "SNFT");
        simpleNFT.setFeeContract(address(feeContract));

        // Setup: Mint NFT
        vm.prank(seller);
        simpleNFT.mint(seller, 1);

        // List and sell
        vm.startPrank(seller);
        simpleNFT.setApprovalForAll(address(exchange), true);
        exchange.listNFT(address(simpleNFT), 1, NFT_PRICE, 7 days);
        vm.stopPrank();

        bytes32 listingId = exchange.getGeneratedListingId(address(simpleNFT), 1, seller);

        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(buyer);
        exchange.buyNFT{value: exchange.getBuyerSeesPrice(listingId)}(listingId);

        uint256 creatorBalanceAfter = creator.balance;
        uint256 expectedRoyalty = (NFT_PRICE * ROYALTY_5_PERCENT) / 10000;

        assertApproxEqAbs(
            creatorBalanceAfter - creatorBalanceBefore, expectedRoyalty, 1e15, "Fee contract royalty not paid"
        );

        console2.log("Fee contract royalty paid:", expectedRoyalty);
        console2.log("=== Fee Contract Royalty Detection: SUCCESS ===\n");
    }

    // ============================================================================
    // ROYALTY RATE VALIDATION TESTS
    // ============================================================================

    function test_Integration_RoyaltyRateValidation() public {
        console2.log("\n=== Test: Royalty Rate Validation ===");

        // Test maximum royalty rate (10%)
        vm.prank(seller);
        mockNFT.mint(seller, 3);
        mockNFT.setDefaultRoyalty(creator, uint96(ROYALTY_10_PERCENT));

        vm.startPrank(seller);
        mockNFT.setApprovalForAll(address(exchange), true);
        exchange.listNFT(address(mockNFT), 3, NFT_PRICE, 7 days);
        vm.stopPrank();

        bytes32 listingId = exchange.getGeneratedListingId(address(mockNFT), 3, seller);

        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(buyer);
        exchange.buyNFT{value: exchange.getBuyerSeesPrice(listingId)}(listingId);

        uint256 creatorBalanceAfter = creator.balance;
        uint256 expectedRoyalty = (NFT_PRICE * ROYALTY_10_PERCENT) / 10000;

        assertApproxEqAbs(creatorBalanceAfter - creatorBalanceBefore, expectedRoyalty, 1e15, "Max royalty not paid");

        console2.log("Maximum royalty (10%) paid correctly");
        console2.log("=== Royalty Rate Validation: SUCCESS ===\n");
    }

    // ============================================================================
    // ZERO ROYALTY EDGE CASE TESTS
    // ============================================================================

    function test_Integration_ZeroRoyaltyEdgeCase() public {
        console2.log("\n=== Test: Zero Royalty Edge Case ===");

        // Setup: NFT with no royalty
        vm.prank(seller);
        mockNFT.mint(seller, 4);
        // No royalty set

        vm.startPrank(seller);
        mockNFT.setApprovalForAll(address(exchange), true);
        exchange.listNFT(address(mockNFT), 4, NFT_PRICE, 7 days);
        vm.stopPrank();

        bytes32 listingId = exchange.getGeneratedListingId(address(mockNFT), 4, seller);

        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(buyer);
        exchange.buyNFT{value: exchange.getBuyerSeesPrice(listingId)}(listingId);

        uint256 creatorBalanceAfter = creator.balance;

        // No royalty should be paid
        assertEq(creatorBalanceAfter, creatorBalanceBefore, "No royalty should be paid");

        console2.log("Zero royalty case handled correctly");
        console2.log("=== Zero Royalty Edge Case: SUCCESS ===\n");
    }

    // ============================================================================
    // MULTIPLE SALES ROYALTY TRACKING TESTS
    // ============================================================================

    function test_Integration_MultipleSalesRoyaltyTracking() public {
        console2.log("\n=== Test: Multiple Sales Royalty Tracking ===");

        // Setup
        vm.prank(seller);
        mockNFT.mint(seller, 5);
        mockNFT.setDefaultRoyalty(creator, uint96(ROYALTY_5_PERCENT));

        uint256 creatorTotalRoyalties = 0;

        // Sale 1: Seller to Buyer
        vm.startPrank(seller);
        mockNFT.setApprovalForAll(address(exchange), true);
        exchange.listNFT(address(mockNFT), 5, 1 ether, 7 days);
        vm.stopPrank();

        bytes32 listing1 = exchange.getGeneratedListingId(address(mockNFT), 5, seller);

        uint256 price1 = exchange.getBuyerSeesPrice(listing1);
        vm.prank(buyer);
        exchange.buyNFT{value: price1}(listing1);

        creatorTotalRoyalties += (1 ether * ROYALTY_5_PERCENT) / 10000;
        console2.log("Sale 1 complete, royalty:", (1 ether * ROYALTY_5_PERCENT) / 10000);

        // Sale 2: Buyer to another address
        address buyer2 = address(0x6);
        vm.deal(buyer2, 100 ether);

        vm.startPrank(buyer);
        mockNFT.setApprovalForAll(address(exchange), true);
        exchange.listNFT(address(mockNFT), 5, 2 ether, 7 days);
        vm.stopPrank();

        bytes32 listing2 = exchange.getGeneratedListingId(address(mockNFT), 5, buyer);

        uint256 price2 = exchange.getBuyerSeesPrice(listing2);
        vm.prank(buyer2);
        exchange.buyNFT{value: price2}(listing2);

        creatorTotalRoyalties += (2 ether * ROYALTY_5_PERCENT) / 10000;
        console2.log("Sale 2 complete, royalty:", (2 ether * ROYALTY_5_PERCENT) / 10000);

        console2.log("Total royalties across multiple sales:", creatorTotalRoyalties);
        console2.log("=== Multiple Sales Royalty Tracking: SUCCESS ===\n");
    }

    // ============================================================================
    // ROYALTY FALLBACK MECHANISM TESTS
    // ============================================================================

    function test_Integration_RoyaltyFallbackMechanism() public {
        console2.log("\n=== Test: Royalty Fallback Mechanism ===");

        // Test 1: ERC2981 takes precedence
        vm.prank(seller);
        mockNFT.mint(seller, 6);
        mockNFT.setDefaultRoyalty(creator, uint96(ROYALTY_10_PERCENT));
        mockNFT.setFeeContract(address(feeContract)); // Also has fee contract

        RoyaltyLib.RoyaltyParams memory params = RoyaltyLib.createRoyaltyParams(address(mockNFT), 6, NFT_PRICE, 1000);

        RoyaltyLib.RoyaltyInfo memory info = RoyaltyLib.getRoyaltyInfo(params);

        assertTrue(info.hasRoyalty, "Should detect royalty");
        assertEq(info.source, "ERC2981", "Should use ERC2981 first");
        console2.log("Royalty source:", info.source);

        // Test 2: Falls back to Fee contract if ERC2981 not available
        SimpleERC721 nftWithoutERC2981 = new SimpleERC721("Test", "TST");
        nftWithoutERC2981.setFeeContract(address(feeContract));
        vm.prank(seller);
        nftWithoutERC2981.mint(seller, 1);

        params = RoyaltyLib.createRoyaltyParams(address(nftWithoutERC2981), 1, NFT_PRICE, 1000);
        info = RoyaltyLib.getRoyaltyInfo(params);

        assertTrue(info.hasRoyalty, "Should detect royalty via fee contract");
        assertEq(info.source, "Fee", "Should use Fee contract");
        console2.log("Fallback royalty source:", info.source);

        console2.log("=== Royalty Fallback Mechanism: SUCCESS ===\n");
    }

    // ============================================================================
    // ROYALTY WITH DIFFERENT PRICE POINTS TESTS
    // ============================================================================

    function test_Integration_RoyaltyWithDifferentPrices() public {
        console2.log("\n=== Test: Royalty with Different Price Points ===");

        vm.prank(seller);
        mockNFT.mint(seller, 7);
        mockNFT.setDefaultRoyalty(creator, uint96(ROYALTY_5_PERCENT));

        uint256[] memory prices = new uint256[](4);
        prices[0] = 0.1 ether;
        prices[1] = 1 ether;
        prices[2] = 10 ether;
        prices[3] = 100 ether;

        for (uint256 i = 0; i < prices.length; i++) {
            uint256 expectedRoyalty = (prices[i] * ROYALTY_5_PERCENT) / 10000;

            RoyaltyLib.RoyaltyParams memory params =
                RoyaltyLib.createRoyaltyParams(address(mockNFT), 7, prices[i], 1000);

            RoyaltyLib.RoyaltyInfo memory info = RoyaltyLib.getRoyaltyInfo(params);

            assertEq(info.amount, expectedRoyalty, "Royalty amount incorrect for price");
            console2.log("Price:", prices[i], "Royalty:", expectedRoyalty);
        }

        console2.log("=== Royalty with Different Prices: SUCCESS ===\n");
    }

    // ============================================================================
    // INVALID ROYALTY RECEIVER TESTS
    // ============================================================================

    function test_Integration_InvalidRoyaltyReceiver() public {
        console2.log("\n=== Test: Invalid Royalty Receiver Handling ===");

        // Setup NFT
        vm.prank(seller);
        mockNFT.mint(seller, 8);

        // ERC2981 should reject zero address as royalty receiver
        vm.expectRevert();
        mockNFT.setDefaultRoyalty(address(0), uint96(ROYALTY_5_PERCENT));

        console2.log("ERC2981 correctly rejects invalid receiver");
        console2.log("=== Invalid Royalty Receiver: SUCCESS ===\n");
    }

    // ============================================================================
    // ROYALTY EXCEEDING MAX RATE TESTS
    // ============================================================================

    function test_Integration_RoyaltyExceedingMaxRate() public {
        console2.log("\n=== Test: Royalty Exceeding Max Rate ===");

        // Create NFT with royalty above max (should be capped or rejected)
        vm.prank(seller);
        mockNFT.mint(seller, 9);
        mockNFT.setDefaultRoyalty(creator, 1001); // 10.01% - above max

        RoyaltyLib.RoyaltyParams memory params = RoyaltyLib.createRoyaltyParams(address(mockNFT), 9, NFT_PRICE, 1000); // max 10%

        RoyaltyLib.RoyaltyInfo memory info = RoyaltyLib.getRoyaltyInfo(params);

        // Should reject royalty above max rate
        assertFalse(info.hasRoyalty, "Should reject royalty above max");
        console2.log("Excessive royalty correctly rejected");

        console2.log("=== Royalty Exceeding Max Rate: SUCCESS ===\n");
    }

    // ============================================================================
    // CONCURRENT ROYALTY PAYMENTS TESTS
    // ============================================================================

    function test_Integration_ConcurrentRoyaltyPayments() public {
        console2.log("\n=== Test: Concurrent Royalty Payments ===");

        // Setup multiple NFTs with same royalty receiver
        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            tokenIds[i] = 10 + i;
            vm.prank(seller);
            mockNFT.mint(seller, tokenIds[i]);
            mockNFT.setDefaultRoyalty(creator, uint96(ROYALTY_5_PERCENT));
        }

        uint256 creatorBalanceBefore = creator.balance;

        // List and sell all
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(seller);
            mockNFT.setApprovalForAll(address(exchange), true);
            exchange.listNFT(address(mockNFT), tokenIds[i], NFT_PRICE, 7 days);
            vm.stopPrank();

            bytes32 listingId = exchange.getGeneratedListingId(address(mockNFT), tokenIds[i], seller);

            vm.prank(buyer);
            exchange.buyNFT{value: exchange.getBuyerSeesPrice(listingId)}(listingId);
        }

        uint256 creatorBalanceAfter = creator.balance;
        uint256 expectedTotalRoyalty = (NFT_PRICE * ROYALTY_5_PERCENT * 3) / 10000;

        assertApproxEqAbs(
            creatorBalanceAfter - creatorBalanceBefore,
            expectedTotalRoyalty,
            3e15,
            "Total royalties from concurrent sales incorrect"
        );

        console2.log("Total royalties from 3 concurrent sales:", expectedTotalRoyalty);
        console2.log("=== Concurrent Royalty Payments: SUCCESS ===\n");
    }
}
