// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";

/**
 * @title GasBenchmarks
 * @notice Gas usage benchmarking for optimization tracking
 * @dev This contract tracks gas consumption for critical functions
 */
contract GasBenchmarks is Test {
    ERC721NFTExchange public exchange;
    MockERC721 public nft;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public marketplace = makeAddr("marketplace");

    uint256 public constant LISTING_DURATION = 7 days;
    uint256 public constant NFT_PRICE = 1 ether;

    // Receive function to accept ETH payments (royalties, etc.)
    receive() external payable {}

    // Gas benchmarks - Update these when optimizations are made
    uint256 public constant TARGET_LIST_GAS = 260_000;
    uint256 public constant TARGET_BUY_GAS = 300_000;
    uint256 public constant TARGET_CANCEL_GAS = 100_000;
    uint256 public constant TARGET_BATCH_LIST_GAS = 222_200; // per NFT

    function setUp() public {
        // Deploy contracts
        exchange = new ERC721NFTExchange();
        exchange.initialize(marketplace, address(this));

        nft = new MockERC721("Test NFT", "TNFT");

        // Setup test accounts
        vm.deal(buyer, 10 ether);
        vm.deal(seller, 1 ether);

        // Mint NFT to seller
        vm.startPrank(seller);
        nft.mint(seller, 1);
        nft.setApprovalForAll(address(exchange), true);
        vm.stopPrank();
    }

    /**
     * @notice Benchmark single NFT listing gas usage
     */
    function test_GasBenchmark_ListSingleNFT() public {
        vm.startPrank(seller);

        uint256 gasBefore = gasleft();
        exchange.listNFT(address(nft), 1, NFT_PRICE, LISTING_DURATION);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Single NFT Listing Gas Used:", gasUsed);
        console2.log("Target Gas Limit:", TARGET_LIST_GAS);

        if (gasUsed > TARGET_LIST_GAS) {
            console2.log("WARNING: Gas usage exceeds target by", gasUsed - TARGET_LIST_GAS);
        } else {
            console2.log("Gas usage within target");
        }

        // Alert if significantly over target (20% tolerance)
        assertLt(gasUsed, (TARGET_LIST_GAS * 120) / 100, "Gas usage significantly exceeds target");

        vm.stopPrank();
    }

    /**
     * @notice Benchmark NFT purchase gas usage
     */
    function test_GasBenchmark_BuySingleNFT() public {
        // First list the NFT
        vm.prank(seller);
        exchange.listNFT(address(nft), 1, NFT_PRICE, LISTING_DURATION);

        bytes32 listingId = exchange.getGeneratedListingId(address(nft), 1, seller);
        uint256 buyerSeesPrice = exchange.getBuyerSeesPrice(listingId);

        vm.startPrank(buyer);

        uint256 gasBefore = gasleft();
        exchange.buyNFT{value: buyerSeesPrice}(listingId);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Single NFT Purchase Gas Used:", gasUsed);
        console2.log("Target Gas Limit:", TARGET_BUY_GAS);

        if (gasUsed > TARGET_BUY_GAS) {
            console2.log("WARNING: Gas usage exceeds target by", gasUsed - TARGET_BUY_GAS);
        } else {
            console2.log("Gas usage within target");
        }

        assertLt(gasUsed, (TARGET_BUY_GAS * 120) / 100, "Gas usage significantly exceeds target");

        vm.stopPrank();
    }

    /**
     * @notice Benchmark batch listing gas efficiency
     */
    function test_GasBenchmark_BatchListNFTs() public {
        uint256 batchSize = 5;
        uint256[] memory tokenIds = new uint256[](batchSize);
        uint256[] memory prices = new uint256[](batchSize);

        // Setup batch data
        for (uint256 i = 0; i < batchSize; i++) {
            tokenIds[i] = i + 2; // Start from tokenId 2
            prices[i] = NFT_PRICE;

            vm.prank(seller);
            nft.mint(seller, tokenIds[i]);
        }

        vm.startPrank(seller);

        uint256 gasBefore = gasleft();
        exchange.batchListNFT(address(nft), tokenIds, prices, LISTING_DURATION);
        uint256 gasUsed = gasBefore - gasleft();
        uint256 gasPerNFT = gasUsed / batchSize;

        console2.log("Batch Listing Total Gas Used:", gasUsed);
        console2.log("Gas Per NFT:", gasPerNFT);
        console2.log("Target Gas Per NFT:", TARGET_BATCH_LIST_GAS);

        if (gasPerNFT > TARGET_BATCH_LIST_GAS) {
            console2.log("WARNING: Gas per NFT exceeds target by", gasPerNFT - TARGET_BATCH_LIST_GAS);
        } else {
            console2.log("Batch gas efficiency within target");
        }

        assertLt(gasPerNFT, (TARGET_BATCH_LIST_GAS * 120) / 100, "Batch gas efficiency exceeds target");

        vm.stopPrank();
    }

    /**
     * @notice Benchmark listing cancellation gas usage
     */
    function test_GasBenchmark_CancelListing() public {
        // First list the NFT
        vm.prank(seller);
        exchange.listNFT(address(nft), 1, NFT_PRICE, LISTING_DURATION);

        bytes32 listingId = exchange.getGeneratedListingId(address(nft), 1, seller);

        vm.startPrank(seller);

        uint256 gasBefore = gasleft();
        exchange.cancelListing(listingId);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Listing Cancellation Gas Used:", gasUsed);
        console2.log("Target Gas Limit:", TARGET_CANCEL_GAS);

        if (gasUsed > TARGET_CANCEL_GAS) {
            console2.log("WARNING: Gas usage exceeds target by", gasUsed - TARGET_CANCEL_GAS);
        } else {
            console2.log("Gas usage within target");
        }

        assertLt(gasUsed, (TARGET_CANCEL_GAS * 120) / 100, "Gas usage significantly exceeds target");

        vm.stopPrank();
    }

    /**
     * @notice Generate gas optimization report
     */
    function test_GenerateGasReport() public view {
        console2.log("");
        console2.log("GAS OPTIMIZATION TARGETS");
        console2.log("============================");
        console2.log("Single NFT Listing:", TARGET_LIST_GAS, "gas");
        console2.log("Single NFT Purchase:", TARGET_BUY_GAS, "gas");
        console2.log("Listing Cancellation:", TARGET_CANCEL_GAS, "gas");
        console2.log("Batch Listing (per NFT):", TARGET_BATCH_LIST_GAS, "gas");
        console2.log("");
        console2.log("Run individual benchmark tests to see current usage");
        console2.log("Tests will fail if gas usage exceeds targets by >20%");
    }
}
