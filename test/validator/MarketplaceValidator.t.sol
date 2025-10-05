// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/validation/MarketplaceValidator.sol";
import "src/core/auction/AuctionFactory.sol";
import {NFTExchangeFactory} from "src/core/NFTExchange/NFTExchangeFactory.sol";
import "src/errors/MarketplaceValidatorErrors.sol";
import "src/errors/AuctionErrors.sol";
import "../mocks/MockERC721.sol";
import "src/core/NFTExchange/ERC721NFTExchange.sol";
import "src/core/NFTExchange/ERC1155NFTExchange.sol";
import "src/core/NFTExchange/ERC721NFTExchange.sol";
import "src/core/NFTExchange/ERC1155NFTExchange.sol";

contract MarketplaceValidatorTest is Test {
    MarketplaceValidator public validator;
    AuctionFactory public auctionFactory;
    NFTExchangeFactory public exchangeFactory;
    MockERC721 public mockNFT;

    address public owner = makeAddr("owner");
    address public seller = address(0x2);
    address public buyer = address(0x3);
    address public marketplaceWallet = address(0x4);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy validator as owner
        validator = new MarketplaceValidator();

        // Deploy mock NFT as owner
        mockNFT = new MockERC721("Test NFT", "TEST");

        // Mint NFTs to seller
        mockNFT.mint(seller, 1);
        mockNFT.mint(seller, 2);

        // Deploy factories as owner
        auctionFactory = new AuctionFactory(marketplaceWallet);
        exchangeFactory = new NFTExchangeFactory(marketplaceWallet);

        if (address(exchangeFactory) != address(0)) {
            address erc721Impl = address(new ERC721NFTExchange());
            address erc1155Impl = address(new ERC1155NFTExchange());
            exchangeFactory.setImplementation(NFTExchangeFactory.ExchangeType.ERC721, erc721Impl);
            exchangeFactory.setImplementation(NFTExchangeFactory.ExchangeType.ERC1155, erc1155Impl);
        }

        // Create exchanges as owner
        address erc721Exchange = exchangeFactory.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        address erc1155Exchange = exchangeFactory.createExchange(NFTExchangeFactory.ExchangeType.ERC1155);

        // Register contracts with validator as owner
        validator.registerExchange(erc721Exchange, 0);
        validator.registerExchange(erc1155Exchange, 1);
        validator.registerAuction(address(auctionFactory), 0); // Register factory, not individual implementations

        // Set validator in auction contracts as owner
        auctionFactory.setMarketplaceValidator(address(validator));

        vm.stopPrank();
    }

    function test_InitialNFTStatus() public {
        // NFT should be available initially
        (bool isAvailable, IMarketplaceValidator.NFTStatus status) =
            validator.isNFTAvailable(address(mockNFT), 1, seller);

        assertTrue(isAvailable);
        assertEq(uint256(status), uint256(IMarketplaceValidator.NFTStatus.AVAILABLE));
    }

    function test_PreventAuctionOfListedNFT() public {
        // First, simulate listing the NFT (would be done by exchange contract)
        vm.prank(exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721)); // ERC721 exchange
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));

        // Verify NFT is listed
        assertTrue(validator.isNFTListed(address(mockNFT), 1, seller));

        // Now try to auction the same NFT - should fail
        vm.startPrank(seller);
        mockNFT.approve(address(auctionFactory), 1);

        vm.expectRevert(Auction__NFTAlreadyListed.selector);
        auctionFactory.createEnglishAuction(address(mockNFT), 1, 1, 1 ether, 1.5 ether, 1 days);
        vm.stopPrank();
    }

    function test_PreventListingOfAuctionedNFT() public {
        // First, create an auction
        vm.startPrank(seller);
        mockNFT.approve(address(auctionFactory), 1);

        bytes32 auctionId = auctionFactory.createEnglishAuction(address(mockNFT), 1, 1, 1 ether, 1.5 ether, 1 days);
        vm.stopPrank();

        // Verify NFT is in auction
        assertTrue(validator.isNFTInAuction(address(mockNFT), 1, seller));

        // Now try to list the same NFT - should fail
        // Note: This would require updating the exchange contracts to use validator
        // For now, we can test the validator logic directly
        vm.prank(exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721));
        vm.expectRevert(MarketplaceValidator__NFTNotAvailable.selector);
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));
    }

    function test_AuctionCancellationMakesNFTAvailable() public {
        // Create auction
        vm.startPrank(seller);
        mockNFT.approve(address(auctionFactory), 1);

        bytes32 auctionId = auctionFactory.createEnglishAuction(address(mockNFT), 1, 1, 1 ether, 1.5 ether, 1 days);

        // Verify NFT is in auction
        assertTrue(validator.isNFTInAuction(address(mockNFT), 1, seller));

        // Cancel auction
        auctionFactory.cancelAuction(auctionId);
        vm.stopPrank();

        // Verify NFT is available again
        (bool isAvailable,) = validator.isNFTAvailable(address(mockNFT), 1, seller);
        assertTrue(isAvailable);
    }

    function test_OnlyRegisteredContractsCanUpdateStatus() public {
        // Try to update status from unregistered address
        vm.prank(address(0x999));
        vm.expectRevert(MarketplaceValidator__NotRegisteredContract.selector);
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));
    }

    function test_OwnerCanRegisterContracts() public {
        address newExchange = address(0x123);

        vm.prank(owner);
        validator.registerExchange(newExchange, 0);

        assertTrue(validator.isRegisteredExchange(newExchange));
    }

    function test_NonOwnerCannotRegisterContracts() public {
        address newExchange = address(0x123);

        vm.prank(seller);
        vm.expectRevert();
        validator.registerExchange(newExchange, 0);
    }

    function test_EmergencyResetNFTStatus() public {
        // Set NFT as listed
        vm.prank(exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721));
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));

        // Verify it's listed
        assertTrue(validator.isNFTListed(address(mockNFT), 1, seller));

        // Emergency reset by owner
        vm.prank(owner);
        validator.emergencyResetNFTStatus(address(mockNFT), 1, seller);

        // Verify it's available again
        (bool isAvailable,) = validator.isNFTAvailable(address(mockNFT), 1, seller);
        assertTrue(isAvailable);
    }

    function test_GetAllRegisteredContracts() public {
        address[] memory exchanges = validator.getAllExchanges();
        address[] memory auctions = validator.getAllAuctions();

        assertEq(exchanges.length, 2); // ERC721 and ERC1155 exchanges
        assertEq(auctions.length, 1); // Auction factory
    }

    function test_NFTStatusAfterSale() public {
        // Simulate NFT sale
        vm.prank(exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721));
        validator.setNFTSold(address(mockNFT), 1, seller, buyer);

        // Old owner should have SOLD status
        IMarketplaceValidator.NFTStatus sellerStatus = validator.getNFTStatus(address(mockNFT), 1, seller);
        assertEq(uint256(sellerStatus), uint256(IMarketplaceValidator.NFTStatus.SOLD));

        // New owner should have AVAILABLE status
        (bool isAvailable,) = validator.isNFTAvailable(address(mockNFT), 1, buyer);
        assertTrue(isAvailable);
    }

    // Test additional edge cases
    function test_MultipleNFTStatusUpdates() public {
        address exchange = exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721);

        // List NFT
        vm.prank(exchange);
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));
        assertTrue(validator.isNFTListed(address(mockNFT), 1, seller));

        // Cancel listing
        vm.prank(exchange);
        validator.setNFTAvailable(address(mockNFT), 1, seller);
        (bool isAvailable,) = validator.isNFTAvailable(address(mockNFT), 1, seller);
        assertTrue(isAvailable);

        // List again
        vm.prank(exchange);
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing2"));
        assertTrue(validator.isNFTListed(address(mockNFT), 1, seller));

        // Sell NFT
        vm.prank(exchange);
        validator.setNFTSold(address(mockNFT), 1, seller, buyer);
        IMarketplaceValidator.NFTStatus status = validator.getNFTStatus(address(mockNFT), 1, seller);
        assertEq(uint256(status), uint256(IMarketplaceValidator.NFTStatus.SOLD));
    }

    // NOTE: unregisterExchange functionality is not implemented yet
    // function test_UnregisterContracts() public {
    //     address exchange = exchangeFactory.getExchangeByType(
    //         NFTExchangeFactory.ExchangeType.ERC721
    //     );

    //     // Verify exchange is registered
    //     assertTrue(validator.isRegisteredExchange(exchange));

    //     // Unregister exchange
    //     vm.prank(owner);
    //     validator.unregisterExchange(exchange);

    //     // Verify exchange is no longer registered
    //     assertFalse(validator.isRegisteredExchange(exchange));

    //     // Try to update NFT status from unregistered exchange
    //     vm.prank(exchange);
    //     vm.expectRevert(MarketplaceValidator__NotRegisteredContract.selector);
    //     validator.setNFTListed(
    //         address(mockNFT),
    //         1,
    //         seller,
    //         bytes32("listing1")
    //     );
    // }

    function test_InvalidContractRegistration() public {
        // Try to register zero address
        vm.prank(owner);
        vm.expectRevert(MarketplaceValidator__ZeroAddress.selector);
        validator.registerExchange(address(0), 0);

        // Note: There's no validation for invalid contract type in the current implementation
        // The contract accepts any uint8 value for exchangeType
        // If type validation is needed, it should be added to the contract
    }

    function test_DuplicateContractRegistration() public {
        address exchange = exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721);

        // Try to register already registered exchange
        vm.prank(owner);
        vm.expectRevert(MarketplaceValidator__AlreadyRegistered.selector);
        validator.registerExchange(exchange, 0);
    }

    function test_BatchNFTStatusOperations() public {
        address exchange = exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721);

        // Batch list multiple NFTs
        vm.startPrank(exchange);
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));
        validator.setNFTListed(address(mockNFT), 2, seller, bytes32("listing2"));
        vm.stopPrank();

        // Verify both are listed
        assertTrue(validator.isNFTListed(address(mockNFT), 1, seller));
        assertTrue(validator.isNFTListed(address(mockNFT), 2, seller));

        // Batch cancel
        vm.startPrank(exchange);
        validator.setNFTAvailable(address(mockNFT), 1, seller);
        validator.setNFTAvailable(address(mockNFT), 2, seller);
        vm.stopPrank();

        // Verify both are available
        (bool isAvailable1,) = validator.isNFTAvailable(address(mockNFT), 1, seller);
        (bool isAvailable2,) = validator.isNFTAvailable(address(mockNFT), 2, seller);
        assertTrue(isAvailable1);
        assertTrue(isAvailable2);
    }

    function test_CrossContractValidation() public {
        address erc721Exchange = exchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721);
        address auctionFactoryAddr = address(auctionFactory);

        // List NFT on exchange
        vm.prank(erc721Exchange);
        validator.setNFTListed(address(mockNFT), 1, seller, bytes32("listing1"));

        // Try to set as auctioned from auction factory - should fail
        vm.prank(auctionFactoryAddr);
        vm.expectRevert(MarketplaceValidator__NFTNotAvailable.selector);
        validator.setNFTInAuction(address(mockNFT), 1, seller, bytes32("auction1"));

        // Cancel listing first
        vm.prank(erc721Exchange);
        validator.setNFTAvailable(address(mockNFT), 1, seller);

        // Now auction should work
        vm.prank(auctionFactoryAddr);
        validator.setNFTInAuction(address(mockNFT), 1, seller, bytes32("auction1"));
        assertTrue(validator.isNFTInAuction(address(mockNFT), 1, seller));
    }
}
