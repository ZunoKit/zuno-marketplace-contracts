// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ERC721NFTExchange} from "src/core/NFTExchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/NFTExchange/ERC1155NFTExchange.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ERC165Support Test
 * @notice Test that Exchange contracts properly support ERC165 interface detection
 * @dev This test ensures that Exchange contracts can respond to supportsInterface calls
 *      without reverting, which fixes the frontend eth_call errors
 */
contract ERC165SupportTest is Test {
    ERC721NFTExchange public erc721Exchange;
    ERC1155NFTExchange public erc1155Exchange;

    address public constant MARKETPLACE_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Interface IDs
    bytes4 public constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 public constant INVALID_INTERFACE_ID = 0xffffffff;

    function setUp() public {
        erc721Exchange = new ERC721NFTExchange();
        erc721Exchange.initialize(MARKETPLACE_WALLET, address(this));
        erc1155Exchange = new ERC1155NFTExchange();
        erc1155Exchange.initialize(MARKETPLACE_WALLET, address(this));
    }

    function test_ERC721Exchange_SupportsERC165() public view {
        // Should support ERC165
        bool supportsERC165 = erc721Exchange.supportsInterface(ERC165_INTERFACE_ID);
        assertTrue(supportsERC165, "ERC721Exchange should support ERC165");
    }

    function test_ERC721Exchange_DoesNotSupportERC721() public view {
        // Should NOT support ERC721 (it's a marketplace, not an NFT)
        bool supportsERC721 = erc721Exchange.supportsInterface(ERC721_INTERFACE_ID);
        assertFalse(supportsERC721, "ERC721Exchange should NOT support ERC721 interface");
    }

    function test_ERC721Exchange_DoesNotSupportERC1155() public view {
        // Should NOT support ERC1155
        bool supportsERC1155 = erc721Exchange.supportsInterface(ERC1155_INTERFACE_ID);
        assertFalse(supportsERC1155, "ERC721Exchange should NOT support ERC1155 interface");
    }

    function test_ERC721Exchange_DoesNotSupportInvalidInterface() public view {
        // Should NOT support invalid interface
        bool supportsInvalid = erc721Exchange.supportsInterface(INVALID_INTERFACE_ID);
        assertFalse(supportsInvalid, "ERC721Exchange should NOT support invalid interface");
    }

    function test_ERC1155Exchange_SupportsERC165() public view {
        // Should support ERC165
        bool supportsERC165 = erc1155Exchange.supportsInterface(ERC165_INTERFACE_ID);
        assertTrue(supportsERC165, "ERC1155Exchange should support ERC165");
    }

    function test_ERC1155Exchange_DoesNotSupportERC721() public view {
        // Should NOT support ERC721
        bool supportsERC721 = erc1155Exchange.supportsInterface(ERC721_INTERFACE_ID);
        assertFalse(supportsERC721, "ERC1155Exchange should NOT support ERC721 interface");
    }

    function test_ERC1155Exchange_DoesNotSupportERC1155() public view {
        // Should NOT support ERC1155 (it's a marketplace, not an NFT)
        bool supportsERC1155 = erc1155Exchange.supportsInterface(ERC1155_INTERFACE_ID);
        assertFalse(supportsERC1155, "ERC1155Exchange should NOT support ERC1155 interface");
    }

    function test_ERC1155Exchange_DoesNotSupportInvalidInterface() public view {
        // Should NOT support invalid interface
        bool supportsInvalid = erc1155Exchange.supportsInterface(INVALID_INTERFACE_ID);
        assertFalse(supportsInvalid, "ERC1155Exchange should NOT support invalid interface");
    }

    function test_NoRevertOnSupportsInterface() public view {
        // The main fix: these calls should NOT revert
        // This was the original issue causing eth_call errors

        // Test all interface IDs on both exchanges
        erc721Exchange.supportsInterface(ERC165_INTERFACE_ID);
        erc721Exchange.supportsInterface(ERC721_INTERFACE_ID);
        erc721Exchange.supportsInterface(ERC1155_INTERFACE_ID);
        erc721Exchange.supportsInterface(INVALID_INTERFACE_ID);

        erc1155Exchange.supportsInterface(ERC165_INTERFACE_ID);
        erc1155Exchange.supportsInterface(ERC721_INTERFACE_ID);
        erc1155Exchange.supportsInterface(ERC1155_INTERFACE_ID);
        erc1155Exchange.supportsInterface(INVALID_INTERFACE_ID);

        // If we reach here, none of the calls reverted
        assertTrue(true, "All supportsInterface calls completed without reverting");
    }

    function test_FrontendCompatibility() public view {
        // Simulate the exact call that was failing in the frontend
        // Address 0xa16e02e87b7454126e5e10d957a927a7f5b5d2be was the old ERC721 Exchange
        // Now we test with the new exchange address

        // This should return false (not revert) for ERC721 interface
        bool result = erc721Exchange.supportsInterface(ERC721_INTERFACE_ID);
        assertFalse(result, "Exchange should return false for ERC721 interface, not revert");

        // This should return true for ERC165 interface
        bool erc165Result = erc721Exchange.supportsInterface(ERC165_INTERFACE_ID);
        assertTrue(erc165Result, "Exchange should return true for ERC165 interface");
    }
}
