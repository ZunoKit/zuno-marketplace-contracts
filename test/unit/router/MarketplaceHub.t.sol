// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MarketplaceHub} from "src/router/MarketplaceHub.sol";
import {ExchangeRegistry} from "src/registry/ExchangeRegistry.sol";
import {CollectionRegistry} from "src/registry/CollectionRegistry.sol";
import {FeeRegistry} from "src/registry/FeeRegistry.sol";
import {AuctionRegistry} from "src/registry/AuctionRegistry.sol";
import {IExchangeRegistry} from "src/interfaces/registry/IExchangeRegistry.sol";
import {IAuctionRegistry} from "src/interfaces/registry/IAuctionRegistry.sol";
import {IFeeRegistry} from "src/interfaces/registry/IFeeRegistry.sol";
import {ListingHistoryTracker} from "src/core/analytics/ListingHistoryTracker.sol";
import {MarketplaceAccessControl} from "src/core/access/MarketplaceAccessControl.sol";

contract MarketplaceHubTest is Test {
    MarketplaceHub hub;
    ExchangeRegistry exchangeRegistry;
    CollectionRegistry collectionRegistry;
    FeeRegistry feeRegistry;
    AuctionRegistry auctionRegistry;
    MarketplaceAccessControl accessControl;

    address admin = makeAddr("admin");
    address erc721Exchange = makeAddr("erc721Exchange");
    address erc1155Exchange = makeAddr("erc1155Exchange");
    address erc721Factory = makeAddr("erc721Factory");
    address erc1155Factory = makeAddr("erc1155Factory");
    address englishAuction = makeAddr("englishAuction");
    address dutchAuction = makeAddr("dutchAuction");
    address auctionFactory = makeAddr("auctionFactory");
    address baseFee = makeAddr("baseFee");
    address feeManager = makeAddr("feeManager");
    address royaltyManager = makeAddr("royaltyManager");

    function setUp() public {
        // Deploy access control
        accessControl = new MarketplaceAccessControl();

        vm.startPrank(admin);

        // Deploy registries
        exchangeRegistry = new ExchangeRegistry(admin);
        collectionRegistry = new CollectionRegistry(admin);
        feeRegistry = new FeeRegistry(
            admin,
            baseFee,
            feeManager,
            royaltyManager
        );
        auctionRegistry = new AuctionRegistry(admin);

        // Deploy hub
        hub = new MarketplaceHub(
            admin,
            address(exchangeRegistry),
            address(collectionRegistry),
            address(feeRegistry),
            address(auctionRegistry),
            address(0x1111),
            address(0x2222),
            address(0x3333) // ListingHistoryTracker
        );

        // Register some contracts
        exchangeRegistry.registerExchange(
            IExchangeRegistry.TokenStandard.ERC721,
            erc721Exchange
        );
        exchangeRegistry.registerExchange(
            IExchangeRegistry.TokenStandard.ERC1155,
            erc1155Exchange
        );
        collectionRegistry.registerFactory("ERC721", erc721Factory);
        collectionRegistry.registerFactory("ERC1155", erc1155Factory);
        auctionRegistry.registerAuction(
            IAuctionRegistry.AuctionType.ENGLISH,
            englishAuction
        );
        auctionRegistry.registerAuction(
            IAuctionRegistry.AuctionType.DUTCH,
            dutchAuction
        );
        auctionRegistry.updateAuctionFactory(auctionFactory);

        vm.stopPrank();
    }

    function test_GetAllAddresses() public {
        (
            address _erc721Exchange,
            address _erc1155Exchange,
            address _erc721Factory,
            address _erc1155Factory,
            address _englishAuction,
            address _dutchAuction,
            address _auctionFactory,
            address _feeRegistry,
            address _bundleManager,
            address _offerManager,
            address _listingHistoryTracker
        ) = hub.getAllAddresses();

        assertEq(_erc721Exchange, erc721Exchange);
        assertEq(_erc1155Exchange, erc1155Exchange);
        assertEq(_erc721Factory, erc721Factory);
        assertEq(_erc1155Factory, erc1155Factory);
        assertEq(_englishAuction, englishAuction);
        assertEq(_dutchAuction, dutchAuction);
        assertEq(_auctionFactory, auctionFactory);
        assertEq(_feeRegistry, address(feeRegistry));
        assertEq(_bundleManager, address(0x1111));
        assertEq(_offerManager, address(0x2222));
        assertEq(_listingHistoryTracker, address(0x3333));
    }

    // ============================================================================
    // LISTING HISTORY TRACKER INTEGRATION TESTS
    // ============================================================================

    function testGetListingHistoryTracker() public {
        address trackerAddress = hub.getListingHistoryTracker();
        assertEq(trackerAddress, address(0x3333));
    }

    function testUpdateRegistryAnalytics() public {
        // Deploy new ListingHistoryTracker
        ListingHistoryTracker newTracker = new ListingHistoryTracker(
            address(accessControl),
            admin
        );

        // Update registry
        vm.prank(admin);
        hub.updateRegistry("analytics", address(newTracker));

        // Verify update
        address trackerAddress = hub.getListingHistoryTracker();
        assertEq(trackerAddress, address(newTracker));
    }

    function testUpdateRegistryAnalyticsOnlyAdmin() public {
        address nonAdmin = makeAddr("nonAdmin");

        // Non-admin should not be able to update registry
        vm.prank(nonAdmin);
        vm.expectRevert();
        hub.updateRegistry("analytics", address(0x3333));
    }

    function testUpdateRegistryAnalyticsZeroAddress() public {
        // Should not be able to set zero address
        vm.prank(admin);
        vm.expectRevert(MarketplaceHub.MarketplaceHub__ZeroAddress.selector);
        hub.updateRegistry("analytics", address(0));
    }

    function testUpdateRegistryInvalidType() public {
        // Should not be able to update with invalid registry type
        vm.prank(admin);
        vm.expectRevert(
            MarketplaceHub.MarketplaceHub__InvalidRegistry.selector
        );
        hub.updateRegistry("invalid", address(0x3333));
    }

    function testListingHistoryTrackerIntegration() public {
        // Test that we can interact with ListingHistoryTracker through Hub
        address trackerAddress = hub.getListingHistoryTracker();
        assertEq(trackerAddress, address(0x3333));
    }

    function testHubConstructorWithZeroListingHistoryTracker() public {
        // Should revert if ListingHistoryTracker is zero address
        vm.expectRevert(MarketplaceHub.MarketplaceHub__ZeroAddress.selector);
        new MarketplaceHub(
            admin,
            address(exchangeRegistry),
            address(collectionRegistry),
            address(feeRegistry),
            address(auctionRegistry),
            address(0x1111),
            address(0x2222),
            address(0) // Zero address should revert
        );
    }

    function testRegistryUpdatedEvent() public {
        ListingHistoryTracker newTracker = new ListingHistoryTracker(
            address(accessControl),
            admin
        );

        // Expect RegistryUpdated event
        vm.expectEmit(true, false, false, true);
        emit MarketplaceHub.RegistryUpdated("analytics", address(newTracker));

        vm.prank(admin);
        hub.updateRegistry("analytics", address(newTracker));
    }

    function test_GetERC721Exchange() public {
        address exchange = hub.getERC721Exchange();
        assertEq(exchange, erc721Exchange);
    }

    function test_GetERC1155Exchange() public {
        address exchange = hub.getERC1155Exchange();
        assertEq(exchange, erc1155Exchange);
    }

    function test_GetCollectionFactory() public {
        address factory = hub.getCollectionFactory("ERC721");
        assertEq(factory, erc721Factory);
    }

    function test_GetRegistryAddresses() public {
        assertEq(hub.getExchangeRegistry(), address(exchangeRegistry));
        assertEq(hub.getCollectionRegistry(), address(collectionRegistry));
        assertEq(hub.getFeeRegistry(), address(feeRegistry));
        assertEq(hub.getAuctionRegistry(), address(auctionRegistry));
    }

    function test_GetAllExchanges() public {
        (
            IExchangeRegistry.TokenStandard[] memory standards,
            address[] memory exchanges
        ) = hub.getAllExchanges();
        assertEq(standards.length, 2);
        assertEq(exchanges.length, 2);

        // Check contents without assuming order
        bool found721 = false;
        bool found1155 = false;
        for (uint256 i = 0; i < standards.length; i++) {
            if (
                standards[i] == IExchangeRegistry.TokenStandard.ERC721 &&
                exchanges[i] == erc721Exchange
            ) {
                found721 = true;
            }
            if (
                standards[i] == IExchangeRegistry.TokenStandard.ERC1155 &&
                exchanges[i] == erc1155Exchange
            ) {
                found1155 = true;
            }
        }
        assertTrue(found721, "ERC721 exchange not found");
        assertTrue(found1155, "ERC1155 exchange not found");
    }

    function test_GetAllFactories() public {
        (string[] memory typesList, address[] memory factories) = hub
            .getAllFactories();
        assertEq(typesList.length, 2);
        assertEq(factories.length, 2);

        bool found721 = false;
        bool found1155 = false;
        for (uint256 i = 0; i < typesList.length; i++) {
            if (
                keccak256(bytes(typesList[i])) == keccak256("ERC721") &&
                factories[i] == erc721Factory
            ) {
                found721 = true;
            }
            if (
                keccak256(bytes(typesList[i])) == keccak256("ERC1155") &&
                factories[i] == erc1155Factory
            ) {
                found1155 = true;
            }
        }
        assertTrue(found721, "ERC721 factory not found");
        assertTrue(found1155, "ERC1155 factory not found");
    }

    function test_GetAllAuctions() public {
        (
            IAuctionRegistry.AuctionType[] memory typesList,
            address[] memory contracts
        ) = hub.getAllAuctions();
        assertEq(typesList.length, 2);
        assertEq(contracts.length, 2);

        bool foundEnglish = false;
        bool foundDutch = false;
        for (uint256 i = 0; i < typesList.length; i++) {
            if (
                typesList[i] == IAuctionRegistry.AuctionType.ENGLISH &&
                contracts[i] == englishAuction
            ) {
                foundEnglish = true;
            }
            if (
                typesList[i] == IAuctionRegistry.AuctionType.DUTCH &&
                contracts[i] == dutchAuction
            ) {
                foundDutch = true;
            }
        }
        assertTrue(foundEnglish, "English auction not found");
        assertTrue(foundDutch, "Dutch auction not found");
    }

    function test_IsRegisteredChecks() public {
        assertTrue(hub.isRegisteredExchange(erc721Exchange));
        assertTrue(hub.isRegisteredExchange(erc1155Exchange));
        assertTrue(hub.isRegisteredFactory(erc721Factory));
        assertTrue(hub.isRegisteredFactory(erc1155Factory));
        assertTrue(hub.isRegisteredAuction(englishAuction));
        assertTrue(hub.isRegisteredAuction(dutchAuction));
    }

    function test_GetFeeContracts() public {
        (
            address baseFeeAddr,
            address feeManagerAddr,
            address royaltyManagerAddr
        ) = hub.getFeeContracts();
        assertEq(baseFeeAddr, baseFee);
        assertEq(feeManagerAddr, feeManager);
        assertEq(royaltyManagerAddr, royaltyManager);
    }

    function test_RevertIf_ZeroAddressInConstructor() public {
        vm.expectRevert(MarketplaceHub.MarketplaceHub__ZeroAddress.selector);
        new MarketplaceHub(
            admin,
            address(0),
            address(collectionRegistry),
            address(feeRegistry),
            address(auctionRegistry),
            address(1),
            address(2),
            address(3)
        );
    }
}
