// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";

// Core Exchange
import {ERC721NFTExchange} from "../../src/core/exchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "../../src/core/exchange/ERC1155NFTExchange.sol";

// Collection System
import {ERC721CollectionFactory} from "../../src/core/factory/ERC721CollectionFactory.sol";
import {ERC1155CollectionFactory} from "../../src/core/factory/ERC1155CollectionFactory.sol";
import {CollectionFactoryRegistry} from "../../src/core/factory/CollectionFactoryRegistry.sol";

// Auction System
import {AuctionFactory} from "../../src/core/factory/AuctionFactory.sol";
import {EnglishAuction} from "../../src/core/auction/EnglishAuction.sol";
import {DutchAuction} from "../../src/core/auction/DutchAuction.sol";

// Fee Management
import {Fee} from "../../src/common/Fee.sol";
import {AdvancedFeeManager} from "../../src/core/fees/AdvancedFeeManager.sol";
import {AdvancedRoyaltyManager} from "../../src/core/fees/AdvancedRoyaltyManager.sol";

// Access Control
import {MarketplaceAccessControl} from "../../src/core/access/MarketplaceAccessControl.sol";

// Hub Architecture
import {MarketplaceHub} from "../../src/router/MarketplaceHub.sol";
import {ExchangeRegistry} from "../../src/registry/ExchangeRegistry.sol";
import {CollectionRegistry} from "../../src/registry/CollectionRegistry.sol";
import {FeeRegistry} from "../../src/registry/FeeRegistry.sol";
import {AuctionRegistry} from "../../src/registry/AuctionRegistry.sol";
import {IExchangeRegistry} from "../../src/interfaces/registry/IExchangeRegistry.sol";
import {IAuctionRegistry} from "../../src/interfaces/registry/IAuctionRegistry.sol";
// Advanced Features
import {OfferManager} from "../../src/core/offers/OfferManager.sol";
import {BundleManager} from "../../src/core/bundles/BundleManager.sol";
import {ListingHistoryTracker} from "../../src/core/analytics/ListingHistoryTracker.sol";

/**
 * @title DeployAll
 * @notice Complete marketplace deployment - deploys EVERYTHING in correct order
 * @dev Run this script to deploy the entire marketplace from scratch
 *
 * Output:
 * - All core contracts deployed
 * - MarketplaceHub deployed and configured
 * - Frontend only needs MarketplaceHub address
 *
 * Usage:
 *   forge script script/deploy/DeployAll.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployAll is Script {
    // Admin
    address public admin;

    // Core Contracts
    ERC721NFTExchange public erc721Exchange;
    ERC1155NFTExchange public erc1155Exchange;

    ERC721CollectionFactory public erc721Factory;
    ERC1155CollectionFactory public erc1155Factory;
    CollectionFactoryRegistry public factoryRegistry;

    AuctionFactory public auctionFactory;
    EnglishAuction public englishAuction;
    DutchAuction public dutchAuction;

    Fee public baseFee;
    AdvancedFeeManager public feeManager;
    AdvancedRoyaltyManager public royaltyManager;

    MarketplaceAccessControl public accessControl;

    // Hub Architecture
    MarketplaceHub public hub;
    ExchangeRegistry public hubExchangeRegistry;
    CollectionRegistry public hubCollectionRegistry;
    FeeRegistry public hubFeeRegistry;
    AuctionRegistry public hubAuctionRegistry;
    // Managers
    OfferManager public offerManager;
    BundleManager public bundleManager;
    ListingHistoryTracker public listingHistoryTracker;

    function setUp() public {
        admin = vm.envAddress("MARKETPLACE_WALLET");
    }

    /**
     * @notice Set admin address (for testing purposes)
     * @param _admin Admin address
     */
    function setAdmin(address _admin) external {
        admin = _admin;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("========================================");
        console.log("  COMPLETE MARKETPLACE DEPLOYMENT");
        console.log("========================================");
        console.log("Admin:", admin);
        console.log("");

        // Deploy in correct order
        _deployAccessControl();
        _grantAdminRoles();
        _deployFees();
        _deployExchanges();
        _deployCollections();
        _deployAuctions();
        _deployAnalytics();
        _deployHub();
        _printSummary();

        vm.stopBroadcast();
    }

    function _deployAccessControl() internal {
        console.log("1/7 Deploying Access Control...");
        accessControl = new MarketplaceAccessControl();
        console.log("  AccessControl:", address(accessControl));
    }

    function _grantAdminRoles() internal {
        console.log("1.5/7 Granting Admin Roles...");

        address deployer = msg.sender;
        if (admin != deployer) {
            accessControl.grantRole(accessControl.DEFAULT_ADMIN_ROLE(), admin);
            accessControl.grantRole(accessControl.ADMIN_ROLE(), admin);
            console.log("  Admin roles granted to:", admin);
        } else {
            console.log("  Admin is deployer, roles already granted");
        }
    }

    function _deployFees() internal {
        console.log("2/7 Deploying Fee System...");
        baseFee = new Fee(admin, 500); // 5% default royalty fee
        feeManager = new AdvancedFeeManager(admin, address(accessControl));
        royaltyManager = new AdvancedRoyaltyManager(
            address(accessControl),
            address(baseFee)
        );

        console.log("  BaseFee:", address(baseFee));
        console.log("  FeeManager:", address(feeManager));
        console.log("  RoyaltyManager:", address(royaltyManager));
    }

    function _deployExchanges() internal {
        console.log("3/7 Deploying Exchanges...");

        erc721Exchange = new ERC721NFTExchange();
        erc721Exchange.initialize(admin, admin);

        erc1155Exchange = new ERC1155NFTExchange();
        erc1155Exchange.initialize(admin, admin);

        console.log("  ERC721Exchange:", address(erc721Exchange));
        console.log("  ERC1155Exchange:", address(erc1155Exchange));
    }

    function _deployCollections() internal {
        console.log("4/7 Deploying Collection Factories...");

        erc721Factory = new ERC721CollectionFactory();
        erc1155Factory = new ERC1155CollectionFactory();
        factoryRegistry = new CollectionFactoryRegistry(
            address(erc721Factory),
            address(erc1155Factory)
        );

        console.log("  ERC721Factory:", address(erc721Factory));
        console.log("  ERC1155Factory:", address(erc1155Factory));
        console.log("  FactoryRegistry:", address(factoryRegistry));
    }

    function _deployAuctions() internal {
        console.log("5/7 Deploying Auction System...");

        auctionFactory = new AuctionFactory(admin);

        // Get implementation addresses from factory
        englishAuction = EnglishAuction(
            auctionFactory.englishAuctionImplementation()
        );
        dutchAuction = DutchAuction(
            auctionFactory.dutchAuctionImplementation()
        );

        console.log("  EnglishAuction:", address(englishAuction));
        console.log("  DutchAuction:", address(dutchAuction));
        console.log("  AuctionFactory:", address(auctionFactory));
    }

    function _deployAnalytics() internal {
        console.log("6/7 Deploying Analytics...");
        listingHistoryTracker = new ListingHistoryTracker(
            address(accessControl),
            admin
        );
        console.log("  ListingHistoryTracker:", address(listingHistoryTracker));
    }

    function _deployAdvancedManagers() internal {
        console.log("6.5/7 Deploying Managers...");
        offerManager = new OfferManager(
            address(accessControl),
            address(feeManager)
        );
        bundleManager = new BundleManager(
            address(accessControl),
            address(feeManager)
        );
        console.log("  OfferManager:", address(offerManager));
        console.log("  BundleManager:", address(bundleManager));
    }

    function _deployHub() internal {
        console.log("7/7 Deploying MarketplaceHub...");

        // Deploy registries (use deployer as admin for testing)
        address deployer = msg.sender;
        hubExchangeRegistry = new ExchangeRegistry(deployer);
        hubCollectionRegistry = new CollectionRegistry(deployer);
        hubFeeRegistry = new FeeRegistry(
            deployer,
            address(baseFee),
            address(feeManager),
            address(royaltyManager)
        );
        hubAuctionRegistry = new AuctionRegistry(deployer);

        // Deploy managers before hub
        _deployAdvancedManagers();

        // Deploy hub
        hub = new MarketplaceHub(
            admin,
            address(hubExchangeRegistry),
            address(hubCollectionRegistry),
            address(hubFeeRegistry),
            address(hubAuctionRegistry),
            address(bundleManager),
            address(offerManager),
            address(listingHistoryTracker)
        );

        // Register all contracts
        _registerContracts();

        console.log("  HubExchangeRegistry:", address(hubExchangeRegistry));
        console.log("  HubCollectionRegistry:", address(hubCollectionRegistry));
        console.log("  HubFeeRegistry:", address(hubFeeRegistry));
        console.log("  HubAuctionRegistry:", address(hubAuctionRegistry));
        console.log("  MarketplaceHub:", address(hub));
    }

    function _printSummary() internal view {
        console.log("");
        console.log("========================================");
        console.log("  DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("CORE CONTRACTS:");
        console.log("  ERC721Exchange:    ", address(erc721Exchange));
        console.log("  ERC1155Exchange:   ", address(erc1155Exchange));
        console.log("  ERC721Factory:     ", address(erc721Factory));
        console.log("  ERC1155Factory:    ", address(erc1155Factory));
        console.log("  EnglishAuction:    ", address(englishAuction));
        console.log("  DutchAuction:      ", address(dutchAuction));
        console.log("  BaseFee:           ", address(baseFee));
        console.log("  FeeManager:        ", address(feeManager));
        console.log("  RoyaltyManager:    ", address(royaltyManager));
        console.log("  OfferManager:      ", address(offerManager));
        console.log("  BundleManager:     ", address(bundleManager));
        console.log(
            "  ListingHistoryTracker: ",
            address(listingHistoryTracker)
        );
        console.log("");
        console.log("========================================");
        console.log("  FOR FRONTEND INTEGRATION");
        console.log("========================================");
        console.log("  MarketplaceHub:    ", address(hub));
        console.log("");
        console.log("Frontend only needs this ONE address!");
        console.log("");
        console.log("Copy this to your .env:");
        console.log("MARKETPLACE_HUB=", address(hub));
        console.log("");
        console.log("========================================");
    }

    /**
     * @notice Register all contracts in their respective registries
     * @dev Uses admin address for privileged operations
     */
    function _registerContracts() internal {
        // For testing, use deployer as admin to avoid role granting issues
        address deployer = msg.sender;
        
        // Register all contracts (deployer has admin role in registries)
        hubExchangeRegistry.registerExchange(
            IExchangeRegistry.TokenStandard.ERC721,
            address(erc721Exchange)
        );
        hubExchangeRegistry.registerExchange(
            IExchangeRegistry.TokenStandard.ERC1155,
            address(erc1155Exchange)
        );

        hubCollectionRegistry.registerFactory("ERC721", address(erc721Factory));
        hubCollectionRegistry.registerFactory(
            "ERC1155",
            address(erc1155Factory)
        );

        hubAuctionRegistry.registerAuction(
            IAuctionRegistry.AuctionType.ENGLISH,
            address(englishAuction)
        );
        hubAuctionRegistry.registerAuction(
            IAuctionRegistry.AuctionType.DUTCH,
            address(dutchAuction)
        );
        hubAuctionRegistry.updateAuctionFactory(address(auctionFactory));
    }

    /**
     * @notice Get all deployed addresses
     * @dev Useful for integration tests
     */
    function getDeployedAddresses()
        external
        view
        returns (
            address _hub,
            address _erc721Exchange,
            address _erc1155Exchange,
            address _erc721Factory,
            address _erc1155Factory,
            address _englishAuction,
            address _dutchAuction,
            address _baseFee,
            address _feeManager,
            address _royaltyManager,
            address _listingHistoryTracker
        )
    {
        return (
            address(hub),
            address(erc721Exchange),
            address(erc1155Exchange),
            address(erc721Factory),
            address(erc1155Factory),
            address(englishAuction),
            address(dutchAuction),
            address(baseFee),
            address(feeManager),
            address(royaltyManager),
            address(listingHistoryTracker)
        );
    }
}
