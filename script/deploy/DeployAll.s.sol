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
import {AdvancedListingManager} from "../../src/core/listing/AdvancedListingManager.sol";

// Security & Validation
import {EmergencyManager} from "../../src/core/security/EmergencyManager.sol";
import {MarketplaceTimelock} from "../../src/core/security/MarketplaceTimelock.sol";
import {ListingValidator} from "../../src/core/validation/ListingValidator.sol";
import {MarketplaceValidator} from "../../src/core/validation/MarketplaceValidator.sol";
import {CollectionVerifier} from "../../src/core/collection/CollectionVerifier.sol";

// Analytics
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
    AdvancedListingManager public listingManager;

    // Security & Validation
    EmergencyManager public emergencyManager;
    MarketplaceTimelock public timelock;
    ListingValidator public listingValidator;
    MarketplaceValidator public marketplaceValidator;
    CollectionVerifier public collectionVerifier;
    
    // Analytics
    ListingHistoryTracker public historyTracker;

    function setUp() public {
        admin = vm.envAddress("MARKETPLACE_WALLET");
    }

    function run() public {
        // Ensure admin is set
        if (admin == address(0)) {
            admin = vm.envAddress("MARKETPLACE_WALLET");
        }
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("========================================");
        console.log("  COMPLETE MARKETPLACE DEPLOYMENT");
        console.log("========================================");
        console.log("Admin:", admin);
        console.log("");

        // Deploy in correct order
        _deployAccessControl();
        _deploySecurityAndValidation();
        _deployFees();
        _deployExchanges();
        _deployCollections();
        _deployAuctions();
        _deployAdvancedManagers();
        _deployAnalytics();
        _deployHub();
        _printSummary();

        vm.stopBroadcast();
    }

    function _deployAccessControl() internal {
        console.log("1/9 Deploying Access Control...");
        accessControl = new MarketplaceAccessControl();
        console.log("  AccessControl:", address(accessControl));
    }

    function _deploySecurityAndValidation() internal {
        console.log("2/9 Deploying Security & Validation...");
        
        // Deploy Emergency Manager
        emergencyManager = new EmergencyManager(address(accessControl));
        console.log("  EmergencyManager:", address(emergencyManager));
        
        // Deploy Timelock (48 hour delay for critical operations)
        timelock = new MarketplaceTimelock();
        console.log("  Timelock:", address(timelock));
        
        // Deploy Validators
        listingValidator = new ListingValidator(address(accessControl));
        marketplaceValidator = new MarketplaceValidator();
        collectionVerifier = new CollectionVerifier(address(accessControl), admin, 0);
        
        console.log("  ListingValidator:", address(listingValidator));
        console.log("  MarketplaceValidator:", address(marketplaceValidator));
        console.log("  CollectionVerifier:", address(collectionVerifier));
    }

    function _deployFees() internal {
        console.log("3/9 Deploying Fee System...");
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
        console.log("4/9 Deploying Exchanges...");

        erc721Exchange = new ERC721NFTExchange();
        erc721Exchange.initialize(admin, admin);

        erc1155Exchange = new ERC1155NFTExchange();
        erc1155Exchange.initialize(admin, admin);

        console.log("  ERC721Exchange:", address(erc721Exchange));
        console.log("  ERC1155Exchange:", address(erc1155Exchange));
    }

    function _deployCollections() internal {
        console.log("5/9 Deploying Collection Factories...");

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
        console.log("6/9 Deploying Auction System...");

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

    function _deployAdvancedManagers() internal {
        console.log("7/9 Deploying Advanced Managers...");
        
        // Deploy Offer Manager
        offerManager = new OfferManager(
            address(accessControl),
            address(feeManager)
        );
        console.log("  OfferManager:", address(offerManager));
        
        // Deploy Bundle Manager
        bundleManager = new BundleManager(
            address(accessControl),
            address(feeManager)
        );
        console.log("  BundleManager:", address(bundleManager));
        
        // Deploy Advanced Listing Manager
        listingManager = new AdvancedListingManager(
            address(accessControl),
            address(listingValidator)
        );
        console.log("  AdvancedListingManager:", address(listingManager));
    }
    
    function _deployAnalytics() internal {
        console.log("8/9 Deploying Analytics...");
        
        // Deploy History Tracker
        historyTracker = new ListingHistoryTracker(
            address(accessControl)
        );
        console.log("  ListingHistoryTracker:", address(historyTracker));
    }

    function _deployHub() internal {
        console.log("9/9 Deploying MarketplaceHub...");

        // Deploy registries
        hubExchangeRegistry = new ExchangeRegistry(admin);
        hubCollectionRegistry = new CollectionRegistry(admin);
        hubFeeRegistry = new FeeRegistry(
            admin,
            address(baseFee),
            address(feeManager),
            address(royaltyManager)
        );
        hubAuctionRegistry = new AuctionRegistry(admin);

        // Deploy hub
        hub = new MarketplaceHub(
            admin,
            address(hubExchangeRegistry),
            address(hubCollectionRegistry),
            address(hubFeeRegistry),
            address(hubAuctionRegistry),
            address(bundleManager),
            address(offerManager)
        );

        // Register all contracts
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
        console.log("  ListingManager:    ", address(listingManager));
        console.log("");
        console.log("SECURITY & VALIDATION:");
        console.log("  EmergencyManager:  ", address(emergencyManager));
        console.log("  Timelock:          ", address(timelock));
        console.log("  ListingValidator:  ", address(listingValidator));
        console.log("  Validator:         ", address(marketplaceValidator));
        console.log("  Verifier:          ", address(collectionVerifier));
        console.log("");
        console.log("ANALYTICS:");
        console.log("  HistoryTracker:    ", address(historyTracker));
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
            address _listingManager,
            address _emergencyManager,
            address _timelock
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
            address(listingManager),
            address(emergencyManager),
            address(timelock)
        );
    }
}
