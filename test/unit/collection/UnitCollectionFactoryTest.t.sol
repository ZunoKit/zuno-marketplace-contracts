// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CollectionFactoryRegistry} from "src/core/factory/CollectionFactoryRegistry.sol";
import {ERC721CollectionFactory} from "src/core/factory/ERC721CollectionFactory.sol";
import {ERC1155CollectionFactory} from "src/core/factory/ERC1155CollectionFactory.sol";
import {CollectionParams} from "src/types/ListingTypes.sol";
import {ERC721CollectionCreated, ERC1155CollectionCreated} from "src/events/CollectionEvents.sol";
import {ICollectionFactory} from "src/interfaces/IMarketplaceCore.sol";

contract UnitCollectionFactoryTest is Test {
    struct TestSetup {
        CollectionFactoryRegistry factory;
        CollectionParams params;
        address owner;
    }

    TestSetup private setup;

    function setUp() public {
        setup.owner = makeAddr("owner");

        // Deploy factories directly
        ERC721CollectionFactory erc721Factory = new ERC721CollectionFactory();
        ERC1155CollectionFactory erc1155Factory = new ERC1155CollectionFactory();

        // Deploy registry
        setup.factory = new CollectionFactoryRegistry(address(erc721Factory), address(erc1155Factory));

        setup.params = CollectionParams({
            owner: setup.owner,
            name: "Test Collection",
            symbol: "TEST",
            description: "Test Description",
            tokenURI: "ipfs://test",
            mintPrice: 0.1 ether,
            maxSupply: 1000,
            mintLimitPerWallet: 5,
            mintStartTime: block.timestamp + 1 days,
            allowlistMintPrice: 0.08 ether,
            publicMintPrice: 0.1 ether,
            allowlistStageDuration: 1 days,
            royaltyFee: 250 // 2.5%
        });
    }

    function test_CreateERC721Collection() public {
        vm.startPrank(setup.owner);
        address collection = setup.factory.createERC721Collection(setup.params);
        vm.stopPrank();

        assertTrue(collection != address(0));
    }

    function test_CreateERC1155Collection() public {
        vm.startPrank(setup.owner);
        address collection = setup.factory.createERC1155Collection(setup.params);
        vm.stopPrank();

        assertTrue(collection != address(0));
    }

    function test_CreateMultipleCollections() public {
        vm.startPrank(setup.owner);

        // Create ERC721 collections
        address collection1 = setup.factory.createERC721Collection(setup.params);
        address collection2 = setup.factory.createERC721Collection(setup.params);

        // Create ERC1155 collections
        address collection3 = setup.factory.createERC1155Collection(setup.params);
        address collection4 = setup.factory.createERC1155Collection(setup.params);

        vm.stopPrank();

        // Verify all collections were created with unique addresses
        assertTrue(collection1 != address(0));
        assertTrue(collection2 != address(0));
        assertTrue(collection3 != address(0));
        assertTrue(collection4 != address(0));
        assertTrue(collection1 != collection2);
        assertTrue(collection3 != collection4);
    }

    function test_Events() public {
        vm.startPrank(setup.owner);

        // Test ERC721 collection creation event
        vm.expectEmit(true, true, true, true);
        address erc721Collection = setup.factory.createERC721Collection(setup.params);
        emit ERC721CollectionCreated(erc721Collection, setup.owner);

        // Test ERC1155 collection creation event
        vm.expectEmit(true, true, true, true);
        address erc1155Collection = setup.factory.createERC1155Collection(setup.params);
        emit ERC1155CollectionCreated(erc1155Collection, setup.owner);

        vm.stopPrank();
    }

    // ============ New Tests for Missing Coverage ============

    function test_GetTotalCollections() public {
        // Initially should be 0
        assertEq(setup.factory.getTotalCollections(), 0);

        vm.startPrank(setup.owner);

        // Create first collection
        setup.factory.createERC721Collection(setup.params);
        assertEq(setup.factory.getTotalCollections(), 1);

        // Create second collection
        setup.factory.createERC1155Collection(setup.params);
        assertEq(setup.factory.getTotalCollections(), 2);

        // Create third collection
        setup.factory.createERC721Collection(setup.params);
        assertEq(setup.factory.getTotalCollections(), 3);

        vm.stopPrank();
    }

    function test_IsValidCollection() public {
        vm.startPrank(setup.owner);

        // Test with non-existent collection
        address fakeCollection = makeAddr("fakeCollection");
        assertFalse(setup.factory.isValidCollection(fakeCollection));

        // Create real collections and test
        address erc721Collection = setup.factory.createERC721Collection(setup.params);
        address erc1155Collection = setup.factory.createERC1155Collection(setup.params);

        assertTrue(setup.factory.isValidCollection(erc721Collection));
        assertTrue(setup.factory.isValidCollection(erc1155Collection));

        // Test with zero address
        assertFalse(setup.factory.isValidCollection(address(0)));

        vm.stopPrank();
    }

    function test_GetSupportedStandards() public {
        string[] memory standards = setup.factory.getSupportedStandards();

        assertEq(standards.length, 2);
        assertEq(standards[0], "ERC721");
        assertEq(standards[1], "ERC1155");
    }

    function test_Version() public {
        string memory version = setup.factory.version();
        assertEq(version, "1.0.0");
    }

    function test_ContractType() public {
        string memory contractType = setup.factory.contractType();
        assertEq(contractType, "CollectionFactoryRegistry");
    }

    function test_IsActive() public {
        bool isActive = setup.factory.isActive();
        assertTrue(isActive);
    }

    function test_SupportsInterface() public {
        // Test ERC165 interface
        assertTrue(setup.factory.supportsInterface(0x01ffc9a7));

        // Test ICollectionFactory interface
        assertTrue(
            setup.factory.supportsInterface(type(ICollectionFactory).interfaceId), "Should support ICollectionFactory"
        );

        // Test invalid interface
        assertFalse(setup.factory.supportsInterface(0x12345678));
    }

    function test_CollectionTrackingIntegration() public {
        vm.startPrank(setup.owner);

        // Verify initial state
        assertEq(setup.factory.getTotalCollections(), 0);

        // Create collections and verify tracking
        address collection1 = setup.factory.createERC721Collection(setup.params);
        assertEq(setup.factory.getTotalCollections(), 1);
        assertTrue(setup.factory.isValidCollection(collection1));

        address collection2 = setup.factory.createERC1155Collection(setup.params);
        assertEq(setup.factory.getTotalCollections(), 2);
        assertTrue(setup.factory.isValidCollection(collection2));

        // Verify both collections are still valid
        assertTrue(setup.factory.isValidCollection(collection1));
        assertTrue(setup.factory.isValidCollection(collection2));

        vm.stopPrank();
    }
}
