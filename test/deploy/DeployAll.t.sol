// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../script/deploy/DeployAll.s.sol";

/**
 * @title DeployAllTest
 * @notice Comprehensive tests for complete marketplace deployment
 */
contract DeployAllTest is Test {
    DeployAll public deployer;
    
    address public constant ADMIN = address(0x1234);
    
    function setUp() public {
        // Set environment variables with actual ADMIN address
        vm.setEnv("MARKETPLACE_WALLET", "0x0000000000000000000000000000000000001234");
        vm.setEnv("PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
        
        deployer = new DeployAll();
    }
    
    function test_DeployAll_Success() public {
        // Prank as the admin for the deployment
        vm.startPrank(ADMIN);
        
        // Execute deployment
        deployer.run();
        
        vm.stopPrank();
        
        // Verify all core contracts deployed
        assertNotEq(address(deployer.erc721Exchange()), address(0), "ERC721 Exchange not deployed");
        assertNotEq(address(deployer.erc1155Exchange()), address(0), "ERC1155 Exchange not deployed");
        assertNotEq(address(deployer.erc721Factory()), address(0), "ERC721 Factory not deployed");
        assertNotEq(address(deployer.erc1155Factory()), address(0), "ERC1155 Factory not deployed");
        assertNotEq(address(deployer.englishAuction()), address(0), "English Auction not deployed");
        assertNotEq(address(deployer.dutchAuction()), address(0), "Dutch Auction not deployed");
        assertNotEq(address(deployer.auctionFactory()), address(0), "Auction Factory not deployed");
        
        // Verify fee contracts
        assertNotEq(address(deployer.baseFee()), address(0), "Base Fee not deployed");
        assertNotEq(address(deployer.feeManager()), address(0), "Fee Manager not deployed");
        assertNotEq(address(deployer.royaltyManager()), address(0), "Royalty Manager not deployed");
        
        // Verify access control
        assertNotEq(address(deployer.accessControl()), address(0), "Access Control not deployed");
        
        // Verify security contracts
        assertNotEq(address(deployer.emergencyManager()), address(0), "Emergency Manager not deployed");
        assertNotEq(address(deployer.timelock()), address(0), "Timelock not deployed");
        
        // Verify validators
        assertNotEq(address(deployer.listingValidator()), address(0), "Listing Validator not deployed");
        assertNotEq(address(deployer.marketplaceValidator()), address(0), "Marketplace Validator not deployed");
        assertNotEq(address(deployer.collectionVerifier()), address(0), "Collection Verifier not deployed");
        
        // Verify managers
        assertNotEq(address(deployer.offerManager()), address(0), "Offer Manager not deployed");
        assertNotEq(address(deployer.bundleManager()), address(0), "Bundle Manager not deployed");
        assertNotEq(address(deployer.listingManager()), address(0), "Listing Manager not deployed");
        
        // Verify analytics
        assertNotEq(address(deployer.historyTracker()), address(0), "History Tracker not deployed");
        
        // Verify hub and registries
        assertNotEq(address(deployer.hub()), address(0), "Marketplace Hub not deployed");
        assertNotEq(address(deployer.hubExchangeRegistry()), address(0), "Exchange Registry not deployed");
        assertNotEq(address(deployer.hubCollectionRegistry()), address(0), "Collection Registry not deployed");
        assertNotEq(address(deployer.hubFeeRegistry()), address(0), "Fee Registry not deployed");
        assertNotEq(address(deployer.hubAuctionRegistry()), address(0), "Auction Registry not deployed");
    }
    
    function test_Hub_Configuration() public {
        deployer.run();
        
        MarketplaceHub hub = deployer.hub();
        
        // Verify hub can retrieve all addresses
        (
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address auctionFactory,
            address feeRegistry,
            address bundleManager,
            address offerManager
        ) = hub.getAllAddresses();
        
        assertEq(erc721Exchange, address(deployer.erc721Exchange()), "ERC721 Exchange mismatch");
        assertEq(erc1155Exchange, address(deployer.erc1155Exchange()), "ERC1155 Exchange mismatch");
        assertEq(erc721Factory, address(deployer.erc721Factory()), "ERC721 Factory mismatch");
        assertEq(erc1155Factory, address(deployer.erc1155Factory()), "ERC1155 Factory mismatch");
        assertEq(englishAuction, address(deployer.englishAuction()), "English Auction mismatch");
        assertEq(dutchAuction, address(deployer.dutchAuction()), "Dutch Auction mismatch");
        assertEq(auctionFactory, address(deployer.auctionFactory()), "Auction Factory mismatch");
        assertEq(bundleManager, address(deployer.bundleManager()), "Bundle Manager mismatch");
        assertEq(offerManager, address(deployer.offerManager()), "Offer Manager mismatch");
    }
    
    function test_Registry_Registrations() public {
        deployer.run();
        
        // Check Exchange Registry
        ExchangeRegistry exchangeRegistry = deployer.hubExchangeRegistry();
        assertEq(
            exchangeRegistry.getExchange(IExchangeRegistry.TokenStandard.ERC721),
            address(deployer.erc721Exchange()),
            "ERC721 Exchange not registered"
        );
        assertEq(
            exchangeRegistry.getExchange(IExchangeRegistry.TokenStandard.ERC1155),
            address(deployer.erc1155Exchange()),
            "ERC1155 Exchange not registered"
        );
        
        // Check Collection Registry
        CollectionRegistry collectionRegistry = deployer.hubCollectionRegistry();
        assertEq(
            collectionRegistry.getFactory("ERC721"),
            address(deployer.erc721Factory()),
            "ERC721 Factory not registered"
        );
        assertEq(
            collectionRegistry.getFactory("ERC1155"),
            address(deployer.erc1155Factory()),
            "ERC1155 Factory not registered"
        );
        
        // Check Auction Registry
        AuctionRegistry auctionRegistry = deployer.hubAuctionRegistry();
        assertEq(
            auctionRegistry.getAuctionContract(IAuctionRegistry.AuctionType.ENGLISH),
            address(deployer.englishAuction()),
            "English Auction not registered"
        );
        assertEq(
            auctionRegistry.getAuctionContract(IAuctionRegistry.AuctionType.DUTCH),
            address(deployer.dutchAuction()),
            "Dutch Auction not registered"
        );
        assertEq(
            auctionRegistry.getAuctionFactory(),
            address(deployer.auctionFactory()),
            "Auction Factory not registered"
        );
    }
    
    function test_Exchange_Initialization() public {
        deployer.run();
        
        ERC721NFTExchange erc721Exchange = deployer.erc721Exchange();
        ERC1155NFTExchange erc1155Exchange = deployer.erc1155Exchange();
        
        // Check initialization
        assertEq(erc721Exchange.owner(), ADMIN, "ERC721 Exchange owner incorrect");
        assertEq(erc1155Exchange.owner(), ADMIN, "ERC1155 Exchange owner incorrect");
        assertEq(erc721Exchange.marketplaceWallet(), ADMIN, "ERC721 marketplace wallet incorrect");
        assertEq(erc1155Exchange.marketplaceWallet(), ADMIN, "ERC1155 marketplace wallet incorrect");
    }
    
    function test_Security_Configuration() public {
        deployer.run();
        
        // Check Emergency Manager
        EmergencyManager emergencyManager = deployer.emergencyManager();
        assertNotEq(address(emergencyManager), address(0), "Emergency Manager not deployed");
        
        // Check Timelock
        MarketplaceTimelock timelock = deployer.timelock();
        assertEq(timelock.customTimelockDuration(), 48 hours, "Timelock duration incorrect");
    }
    
    function test_Validators_Configuration() public {
        deployer.run();
        
        // Check Listing Validator
        ListingValidator listingValidator = deployer.listingValidator();
        assertNotEq(address(listingValidator), address(0), "Listing Validator not deployed");
        
        // Check Collection Verifier
        CollectionVerifier verifier = deployer.collectionVerifier();
        assertEq(verifier.feeRecipient(), ADMIN, "Collection Verifier fee recipient incorrect");
        assertEq(verifier.verificationFee(), 0, "Collection Verifier fee should be 0");
    }
    
    function test_GetDeployedAddresses() public {
        deployer.run();
        
        (
            address hub,
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address listingManager,
            address emergencyManager,
            address timelock
        ) = deployer.getDeployedAddresses();
        
        assertEq(hub, address(deployer.hub()), "Hub address mismatch");
        assertEq(erc721Exchange, address(deployer.erc721Exchange()), "ERC721 Exchange address mismatch");
        assertEq(erc1155Exchange, address(deployer.erc1155Exchange()), "ERC1155 Exchange address mismatch");
        assertEq(erc721Factory, address(deployer.erc721Factory()), "ERC721 Factory address mismatch");
        assertEq(erc1155Factory, address(deployer.erc1155Factory()), "ERC1155 Factory address mismatch");
        assertEq(englishAuction, address(deployer.englishAuction()), "English Auction address mismatch");
        assertEq(dutchAuction, address(deployer.dutchAuction()), "Dutch Auction address mismatch");
        assertEq(listingManager, address(deployer.listingManager()), "Listing Manager address mismatch");
        assertEq(emergencyManager, address(deployer.emergencyManager()), "Emergency Manager address mismatch");
        assertEq(timelock, address(deployer.timelock()), "Timelock address mismatch");
    }
}
