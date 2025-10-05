// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockERC721} from "../../mocks/MockERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title MockERC721Test
 * @notice Unit tests for MockERC721 contract
 */
contract MockERC721Test is Test {
    MockERC721 public mockNFT;
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        mockNFT = new MockERC721("MockNFT", "MNFT");
    }

    // ============================================================================
    // BASIC FUNCTIONALITY TESTS
    // ============================================================================

    function test_Constructor() public {
        assertEq(mockNFT.name(), "MockNFT");
        assertEq(mockNFT.symbol(), "MNFT");
        assertEq(mockNFT.getCurrentTokenId(), 0);
    }

    function test_Mint() public {
        mockNFT.mint(user1, 1);

        assertEq(mockNFT.ownerOf(1), user1);
        assertEq(mockNFT.balanceOf(user1), 1);
        assertTrue(mockNFT.exists(1));
    }

    function test_BatchMint() public {
        uint256 quantity = 5;
        mockNFT.batchMint(user1, quantity);

        assertEq(mockNFT.balanceOf(user1), quantity);
        assertEq(mockNFT.getCurrentTokenId(), quantity);

        // Check all tokens were minted
        for (uint256 i = 1; i <= quantity; i++) {
            assertEq(mockNFT.ownerOf(i), user1);
            assertTrue(mockNFT.exists(i));
        }
    }

    function test_BatchMint_ZeroQuantity() public {
        mockNFT.batchMint(user1, 0);

        assertEq(mockNFT.balanceOf(user1), 0);
        assertEq(mockNFT.getCurrentTokenId(), 0);
    }

    function test_Burn() public {
        mockNFT.mint(user1, 1);
        assertEq(mockNFT.ownerOf(1), user1);

        vm.prank(user1);
        mockNFT.burn(1);

        assertFalse(mockNFT.exists(1));
        assertEq(mockNFT.balanceOf(user1), 0);
    }

    function test_Burn_NonExistentToken() public {
        vm.expectRevert();
        mockNFT.burn(999);
    }

    function test_Exists() public {
        assertFalse(mockNFT.exists(1));

        mockNFT.mint(user1, 1);
        assertTrue(mockNFT.exists(1));

        vm.prank(user1);
        mockNFT.burn(1);
        assertFalse(mockNFT.exists(1));
    }

    // ============================================================================
    // ROYALTY TESTS
    // ============================================================================

    function test_DefaultRoyalty() public {
        mockNFT.mint(user1, 1);

        (address receiver, uint256 royaltyAmount) = mockNFT.royaltyInfo(1, 1000);
        assertEq(receiver, owner); // Constructor sets msg.sender as default royalty receiver
        assertEq(royaltyAmount, 50); // 5% of 1000 = 50
    }

    function test_SetDefaultRoyalty() public {
        mockNFT.setDefaultRoyalty(user2, 1000); // 10%
        mockNFT.mint(user1, 1);

        (address receiver, uint256 royaltyAmount) = mockNFT.royaltyInfo(1, 1000);
        assertEq(receiver, user2);
        assertEq(royaltyAmount, 100); // 10% of 1000 = 100
    }

    function test_SetTokenRoyalty() public {
        mockNFT.mint(user1, 1);
        mockNFT.setTokenRoyalty(1, user2, 750); // 7.5%

        (address receiver, uint256 royaltyAmount) = mockNFT.royaltyInfo(1, 1000);
        assertEq(receiver, user2);
        assertEq(royaltyAmount, 75); // 7.5% of 1000 = 75
    }

    function test_TokenRoyalty_OverridesDefault() public {
        // Set default royalty
        mockNFT.setDefaultRoyalty(user1, 500); // 5%

        // Mint token
        mockNFT.mint(user1, 1);

        // Set specific token royalty
        mockNFT.setTokenRoyalty(1, user2, 1000); // 10%

        // Token-specific royalty should override default
        (address receiver, uint256 royaltyAmount) = mockNFT.royaltyInfo(1, 1000);
        assertEq(receiver, user2);
        assertEq(royaltyAmount, 100); // 10% of 1000 = 100
    }

    function test_RoyaltyInfo_NonExistentToken() public {
        // Should still return royalty info even for non-existent tokens
        (address receiver, uint256 royaltyAmount) = mockNFT.royaltyInfo(999, 1000);
        assertEq(receiver, owner); // Default royalty receiver
        assertEq(royaltyAmount, 50); // 5% of 1000 = 50
    }

    // ============================================================================
    // INTERFACE SUPPORT TESTS
    // ============================================================================

    function test_SupportsInterface_ERC721() public {
        assertTrue(mockNFT.supportsInterface(type(IERC721).interfaceId));
    }

    function test_SupportsInterface_ERC2981() public {
        assertTrue(mockNFT.supportsInterface(type(IERC2981).interfaceId));
    }

    function test_SupportsInterface_ERC165() public {
        assertTrue(mockNFT.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterface_InvalidInterface() public {
        assertFalse(mockNFT.supportsInterface(0x12345678));
    }

    // ============================================================================
    // EDGE CASES AND ERROR TESTS
    // ============================================================================

    function test_Mint_ToZeroAddress() public {
        vm.expectRevert();
        mockNFT.mint(address(0), 1);
    }

    function test_Mint_ExistingToken() public {
        mockNFT.mint(user1, 1);

        vm.expectRevert();
        mockNFT.mint(user2, 1);
    }

    function test_OwnerOf_NonExistentToken() public {
        vm.expectRevert();
        mockNFT.ownerOf(999);
    }

    function test_Transfer() public {
        mockNFT.mint(user1, 1);

        vm.prank(user1);
        mockNFT.transferFrom(user1, user2, 1);

        assertEq(mockNFT.ownerOf(1), user2);
        assertEq(mockNFT.balanceOf(user1), 0);
        assertEq(mockNFT.balanceOf(user2), 1);
    }

    function test_Approve() public {
        mockNFT.mint(user1, 1);

        vm.prank(user1);
        mockNFT.approve(user2, 1);

        assertEq(mockNFT.getApproved(1), user2);
    }

    function test_SetApprovalForAll() public {
        vm.prank(user1);
        mockNFT.setApprovalForAll(user2, true);

        assertTrue(mockNFT.isApprovedForAll(user1, user2));
    }

    function test_BatchMint_LargeQuantity() public {
        uint256 quantity = 100;
        mockNFT.batchMint(user1, quantity);

        assertEq(mockNFT.balanceOf(user1), quantity);
        assertEq(mockNFT.getCurrentTokenId(), quantity);
    }

    function test_GetCurrentTokenId_AfterMints() public {
        assertEq(mockNFT.getCurrentTokenId(), 0);

        mockNFT.batchMint(user1, 3);
        assertEq(mockNFT.getCurrentTokenId(), 3);

        mockNFT.batchMint(user2, 2);
        assertEq(mockNFT.getCurrentTokenId(), 5);
    }

    function test_RoyaltyCalculation_EdgeCases() public {
        mockNFT.setDefaultRoyalty(user1, 10000); // 100% royalty

        (address receiver, uint256 royaltyAmount) = mockNFT.royaltyInfo(1, 1000);
        assertEq(receiver, user1);
        assertEq(royaltyAmount, 1000); // 100% of 1000 = 1000

        // Test with zero sale price
        (receiver, royaltyAmount) = mockNFT.royaltyInfo(1, 0);
        assertEq(receiver, user1);
        assertEq(royaltyAmount, 0); // 100% of 0 = 0
    }
}
