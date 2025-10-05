// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721Collection} from "src/core/collection/ERC721Collection.sol";
import {CollectionParams} from "src/types/ListingTypes.sol";
import {Minted, BatchMinted} from "src/events/CollectionEvents.sol";
import "src/errors/CollectionErrors.sol";
import {MintStage} from "src/types/ListingTypes.sol";

contract UnitERC721CollectionTest is Test {
    struct TestSetup {
        ERC721Collection collection;
        CollectionParams params;
        address owner;
        address user;
    }

    TestSetup private setup;

    function setUp() public {
        setup.owner = makeAddr("owner");
        setup.user = makeAddr("user");
        vm.startPrank(setup.owner);
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
        setup.collection = new ERC721Collection(setup.params);
        vm.stopPrank();
    }

    function test_Mint() public {
        vm.warp(setup.params.mintStartTime + setup.params.allowlistStageDuration + 1);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.publicMintPrice);

        vm.startPrank(setup.user);
        vm.expectEmit(true, true, true, true);
        emit Minted(setup.user, 1, 1);
        setup.collection.mint{value: setup.params.publicMintPrice}(setup.user);
        vm.stopPrank();

        assertEq(setup.collection.ownerOf(1), setup.user, "User should own token 1");
        assertEq(setup.collection.getTotalMinted(), 1, "Total minted should be 1");
        assertEq(setup.collection.getMintedPerWallet(setup.user), 1, "User should have minted 1 token");
    }

    function test_BatchMint() public {
        vm.warp(setup.params.mintStartTime + setup.params.allowlistStageDuration + 1);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.publicMintPrice * 3);

        vm.startPrank(setup.user);
        vm.expectEmit(true, true, true, true);
        emit BatchMinted(setup.user, 3);
        setup.collection.batchMintERC721{value: setup.params.publicMintPrice * 3}(setup.user, 3);
        vm.stopPrank();

        for (uint256 i = 1; i <= 3; i++) {
            assertEq(setup.collection.ownerOf(i), setup.user, string.concat("User should own token ", vm.toString(i)));
        }
        assertEq(setup.collection.getTotalMinted(), 3, "Total minted should be 3");
        assertEq(setup.collection.getMintedPerWallet(setup.user), 3, "User should have minted 3 tokens");
    }

    function test_TokenURI() public {
        vm.warp(setup.params.mintStartTime + setup.params.allowlistStageDuration + 1);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.publicMintPrice);

        vm.startPrank(setup.user);
        setup.collection.mint{value: setup.params.publicMintPrice}(setup.user);
        vm.stopPrank();

        string memory expectedURI = string(abi.encodePacked(setup.params.tokenURI, "/1.json"));
        assertEq(setup.collection.tokenURI(1), expectedURI, "Token URI should match expected format");
    }

    function test_RoyaltyInfo() public {
        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = setup.collection.royaltyInfo(1, salePrice);

        assertEq(receiver, setup.owner, "Owner should receive royalties");
        assertEq(royaltyAmount, (salePrice * setup.params.royaltyFee) / 10000, "Royalty amount should be correct");
    }

    function test_SupportsInterface() public {
        assertTrue(setup.collection.supportsInterface(0x80ac58cd), "Should support ERC721");
        assertTrue(setup.collection.supportsInterface(0x5b5e139f), "Should support ERC721Metadata");
        assertTrue(setup.collection.supportsInterface(0x2a55205a), "Should support ERC2981");
        assertFalse(setup.collection.supportsInterface(0x12345678), "Should not support random interface");
    }

    function test_Mint_InsufficientPayment() public {
        vm.warp(setup.params.mintStartTime + setup.params.allowlistStageDuration + 1);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.publicMintPrice - 1);

        vm.startPrank(setup.user);
        vm.expectRevert(Collection__InsufficientPayment.selector);
        setup.collection.mint{value: setup.params.publicMintPrice - 1}(setup.user);
        vm.stopPrank();
    }

    function test_BatchMint_InsufficientPayment() public {
        vm.warp(setup.params.mintStartTime + setup.params.allowlistStageDuration + 1);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.publicMintPrice * 3 - 1);

        vm.startPrank(setup.user);
        vm.expectRevert(Collection__InsufficientPayment.selector);
        setup.collection.batchMintERC721{value: setup.params.publicMintPrice * 3 - 1}(setup.user, 3);
        vm.stopPrank();
    }

    function test_Mint_NotStarted() public {
        vm.deal(setup.user, setup.params.publicMintPrice);

        vm.startPrank(setup.user);
        vm.expectRevert(Collection__MintingNotActive.selector);
        setup.collection.mint{value: setup.params.publicMintPrice}(setup.user);
        vm.stopPrank();
    }

    function test_Mint_NotActive() public {
        vm.warp(setup.params.mintStartTime - 1);
        vm.deal(setup.user, setup.params.publicMintPrice);

        vm.startPrank(setup.user);
        vm.expectRevert(Collection__MintingNotActive.selector);
        setup.collection.mint{value: setup.params.publicMintPrice}(setup.user);
        vm.stopPrank();
    }

    function test_Mint_NotInAllowlist() public {
        vm.warp(setup.params.mintStartTime);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.allowlistMintPrice);

        vm.startPrank(setup.user);
        vm.expectRevert(Collection__NotInAllowlist.selector);
        setup.collection.mint{value: setup.params.allowlistMintPrice}(setup.user);
        vm.stopPrank();
    }

    function test_Mint_Allowlist() public {
        vm.warp(setup.params.mintStartTime);
        setup.collection.updateMintStage();
        vm.deal(setup.user, setup.params.allowlistMintPrice);

        vm.startPrank(setup.owner);
        address[] memory addresses = new address[](1);
        addresses[0] = setup.user;
        setup.collection.addToAllowlist(addresses);
        vm.stopPrank();

        vm.startPrank(setup.user);
        vm.expectEmit(true, true, true, true);
        emit Minted(setup.user, 1, 1);
        setup.collection.mint{value: setup.params.allowlistMintPrice}(setup.user);
        vm.stopPrank();

        assertEq(setup.collection.ownerOf(1), setup.user, "User should own token 1");
        assertEq(setup.collection.getTotalMinted(), 1, "Total minted should be 1");
        assertEq(setup.collection.getMintedPerWallet(setup.user), 1, "User should have minted 1 token");
    }
}
