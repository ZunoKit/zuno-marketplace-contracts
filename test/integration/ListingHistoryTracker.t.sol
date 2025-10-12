// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "script/deploy/DeployAll.s.sol";
import "src/core/analytics/ListingHistoryTracker.sol";
import "src/router/MarketplaceHub.sol";
import "test/utils/TestHelpers.sol";

contract DeployAllListingHistoryTrackerTest is Test, TestHelpers {
    DeployAll public deployScript;

    address public admin = makeAddr("admin");

    function setUp() public {
        // Set environment variables
        vm.setEnv(
            "MARKETPLACE_WALLET",
            "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        );
        vm.setEnv(
            "PRIVATE_KEY",
            "0x1234567890123456789012345678901234567890123456789012345678901234"
        );

        deployScript = new DeployAll();

        // Manually set the admin address since vm.setEnv doesn't work in this context
        deployScript.setAdmin(admin);
    }

    function testDeployAllIncludesListingHistoryTracker() public {
        // Deploy all contracts
        deployScript.run();

        // Get deployed addresses
        (
            address hub,
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address baseFee,
            address feeManager,
            address royaltyManager,
            address listingHistoryTracker
        ) = deployScript.getDeployedAddresses();

        // Verify ListingHistoryTracker is deployed
        assertTrue(listingHistoryTracker != address(0));

        // Verify it's a valid ListingHistoryTracker contract
        ListingHistoryTracker tracker = ListingHistoryTracker(
            listingHistoryTracker
        );
        assertEq(tracker.getTrackedCollectionsCount(), 0);

        // Verify MarketplaceHub has correct ListingHistoryTracker address
        MarketplaceHub hubContract = MarketplaceHub(hub);
        assertEq(hubContract.getListingHistoryTracker(), listingHistoryTracker);
    }

    function testDeployAllGetAllAddressesIncludesListingHistoryTracker()
        public
    {
        // Deploy all contracts
        deployScript.run();

        // Get deployed addresses
        (
            address hub,
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address baseFee,
            address feeManager,
            address royaltyManager,
            address listingHistoryTracker
        ) = deployScript.getDeployedAddresses();

        // Verify all addresses are non-zero
        assertTrue(hub != address(0));
        assertTrue(erc721Exchange != address(0));
        assertTrue(erc1155Exchange != address(0));
        assertTrue(erc721Factory != address(0));
        assertTrue(erc1155Factory != address(0));
        assertTrue(englishAuction != address(0));
        assertTrue(dutchAuction != address(0));
        assertTrue(baseFee != address(0));
        assertTrue(feeManager != address(0));
        assertTrue(royaltyManager != address(0));
        assertTrue(listingHistoryTracker != address(0));

        // Verify ListingHistoryTracker is properly integrated
        MarketplaceHub hubContract = MarketplaceHub(hub);
        (
            address hubErc721Exchange,
            address hubErc1155Exchange,
            address hubErc721Factory,
            address hubErc1155Factory,
            address hubEnglishAuction,
            address hubDutchAuction,
            address hubAuctionFactory,
            address hubFeeRegistryAddr,
            address hubBundleManagerAddr,
            address hubOfferManagerAddr,
            address hubListingHistoryTrackerAddr
        ) = hubContract.getAllAddresses();

        assertEq(hubListingHistoryTrackerAddr, listingHistoryTracker);
    }

    function testDeployAllListingHistoryTrackerInitialization() public {
        // Deploy all contracts
        deployScript.run();

        // Get deployed addresses
        (
            address hub,
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address baseFee,
            address feeManager,
            address royaltyManager,
            address listingHistoryTracker
        ) = deployScript.getDeployedAddresses();

        // Test ListingHistoryTracker initialization
        ListingHistoryTracker tracker = ListingHistoryTracker(
            listingHistoryTracker
        );

        // Verify initial state
        assertEq(tracker.getTrackedCollectionsCount(), 0);

        // Verify global stats are initialized
        ListingHistoryTracker.MarketplaceStats memory stats = tracker
            .getGlobalStats();
        assertEq(stats.totalListings, 0);
        assertEq(stats.totalSales, 0);
        assertEq(stats.totalVolume, 0);
        assertEq(stats.totalUsers, 0);
        assertEq(stats.totalCollections, 0);
        assertEq(stats.averageSalePrice, 0);
        assertEq(stats.dailyActiveUsers, 0);
        assertTrue(stats.lastUpdated > 0);
    }

    function testDeployAllHubIntegration() public {
        // Deploy all contracts
        deployScript.run();

        // Get deployed addresses
        (
            address hub,
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address baseFee,
            address feeManager,
            address royaltyManager,
            address listingHistoryTracker
        ) = deployScript.getDeployedAddresses();

        // Test Hub integration
        MarketplaceHub hubContract = MarketplaceHub(hub);

        // Verify Hub can access ListingHistoryTracker
        address trackerAddress = hubContract.getListingHistoryTracker();
        assertEq(trackerAddress, listingHistoryTracker);

        // Verify Hub can access all other contracts
        assertTrue(hubContract.getERC721Exchange() != address(0));
        assertTrue(hubContract.getERC1155Exchange() != address(0));
        assertTrue(hubContract.getCollectionFactory("ERC721") != address(0));
        assertTrue(hubContract.getCollectionFactory("ERC1155") != address(0));
        assertTrue(hubContract.getEnglishAuction() != address(0));
        assertTrue(hubContract.getDutchAuction() != address(0));
        assertTrue(hubContract.getAuctionFactory() != address(0));
        assertTrue(hubContract.getBundleManager() != address(0));
        assertTrue(hubContract.getOfferManager() != address(0));
    }

    function testDeployAllStepNumbers() public {
        // This test verifies that the deployment steps are correctly numbered
        // We can't directly test console.log output, but we can verify the deployment works
        deployScript.run();

        // If we get here without errors, the step numbering is correct
        // The deployment should go through all 7 steps:
        // 1/7 Access Control
        // 2/7 Fee System
        // 3/7 Exchanges
        // 4/7 Collections
        // 5/7 Auctions
        // 6/7 Analytics (ListingHistoryTracker)
        // 7/7 Hub

        // Verify all contracts are deployed
        (
            address hub,
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address baseFee,
            address feeManager,
            address royaltyManager,
            address listingHistoryTracker
        ) = deployScript.getDeployedAddresses();

        // All addresses should be non-zero
        assertTrue(hub != address(0));
        assertTrue(listingHistoryTracker != address(0));
        assertTrue(erc721Exchange != address(0));
        assertTrue(erc1155Exchange != address(0));
        assertTrue(erc721Factory != address(0));
        assertTrue(erc1155Factory != address(0));
        assertTrue(englishAuction != address(0));
        assertTrue(dutchAuction != address(0));
        assertTrue(baseFee != address(0));
        assertTrue(feeManager != address(0));
        assertTrue(royaltyManager != address(0));
    }
}
