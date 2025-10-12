// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/validation/MarketplaceValidator.sol";
import "src/errors/MarketplaceValidatorErrors.sol";

contract SimpleValidatorTest is Test {
    MarketplaceValidator public validator;

    address public mockExchange = address(0x123);
    address public mockAuction = address(0x456);
    address public mockNFT = address(0x789);
    address public seller = address(0x2);

    function setUp() public {
        validator = new MarketplaceValidator();
    }

    function test_InitialState() public {
        // NFT should be available initially
        (bool isAvailable, IMarketplaceValidator.NFTStatus status) = validator.isNFTAvailable(mockNFT, 1, seller);

        assertTrue(isAvailable);
        assertEq(uint256(status), uint256(IMarketplaceValidator.NFTStatus.AVAILABLE));
    }

    function test_RegisterExchange() public {
        validator.registerExchange(mockExchange, 0);
        assertTrue(validator.isRegisteredExchange(mockExchange));
    }

    function test_RegisterAuction() public {
        validator.registerAuction(mockAuction, 0);
        assertTrue(validator.isRegisteredAuction(mockAuction));
    }

    function test_SetNFTListed() public {
        // Register exchange first
        validator.registerExchange(mockExchange, 0);

        // Set NFT as listed
        vm.prank(mockExchange);
        validator.setNFTListed(mockNFT, 1, seller, bytes32("listing1"));

        // Verify it's listed
        assertTrue(validator.isNFTListed(mockNFT, 1, seller));
        assertFalse(validator.isNFTInAuction(mockNFT, 1, seller));
    }

    function test_SetNFTInAuction() public {
        // Register auction first
        validator.registerAuction(mockAuction, 0);

        // Set NFT in auction
        vm.prank(mockAuction);
        validator.setNFTInAuction(mockNFT, 1, seller, bytes32("auction1"));

        // Verify it's in auction
        assertTrue(validator.isNFTInAuction(mockNFT, 1, seller));
        assertFalse(validator.isNFTListed(mockNFT, 1, seller));
    }

    function test_PreventDoubleListingAuction() public {
        // Register both
        validator.registerExchange(mockExchange, 0);
        validator.registerAuction(mockAuction, 0);

        // List NFT first
        vm.prank(mockExchange);
        validator.setNFTListed(mockNFT, 1, seller, bytes32("listing1"));

        // Try to auction same NFT - should fail
        vm.prank(mockAuction);
        vm.expectRevert(MarketplaceValidator__NFTNotAvailable.selector);
        validator.setNFTInAuction(mockNFT, 1, seller, bytes32("auction1"));
    }

    function test_PreventDoubleAuctionListing() public {
        // Register both
        validator.registerExchange(mockExchange, 0);
        validator.registerAuction(mockAuction, 0);

        // Auction NFT first
        vm.prank(mockAuction);
        validator.setNFTInAuction(mockNFT, 1, seller, bytes32("auction1"));

        // Try to list same NFT - should fail
        vm.prank(mockExchange);
        vm.expectRevert(MarketplaceValidator__NFTNotAvailable.selector);
        validator.setNFTListed(mockNFT, 1, seller, bytes32("listing1"));
    }

    function test_SetNFTAvailable() public {
        // Register and list NFT
        validator.registerExchange(mockExchange, 0);
        vm.prank(mockExchange);
        validator.setNFTListed(mockNFT, 1, seller, bytes32("listing1"));

        // Make it available again
        vm.prank(mockExchange);
        validator.setNFTAvailable(mockNFT, 1, seller);

        // Verify it's available
        (bool isAvailable,) = validator.isNFTAvailable(mockNFT, 1, seller);
        assertTrue(isAvailable);
    }

    function test_OnlyRegisteredContractsCanUpdate() public {
        // Try to update from unregistered address
        vm.expectRevert(MarketplaceValidator__NotRegisteredContract.selector);
        validator.setNFTListed(mockNFT, 1, seller, bytes32("listing1"));
    }

    function test_EmergencyReset() public {
        // Register and list NFT
        validator.registerExchange(mockExchange, 0);
        vm.prank(mockExchange);
        validator.setNFTListed(mockNFT, 1, seller, bytes32("listing1"));

        // Emergency reset
        validator.emergencyResetNFTStatus(mockNFT, 1, seller);

        // Verify it's available
        (bool isAvailable,) = validator.isNFTAvailable(mockNFT, 1, seller);
        assertTrue(isAvailable);
    }

    function test_GetAllContracts() public {
        validator.registerExchange(mockExchange, 0);
        validator.registerAuction(mockAuction, 0);

        address[] memory exchanges = validator.getAllExchanges();
        address[] memory auctions = validator.getAllAuctions();

        assertEq(exchanges.length, 1);
        assertEq(auctions.length, 1);
        assertEq(exchanges[0], mockExchange);
        assertEq(auctions[0], mockAuction);
    }
}
