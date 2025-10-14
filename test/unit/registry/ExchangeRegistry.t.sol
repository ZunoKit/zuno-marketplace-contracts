// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ExchangeRegistry} from "src/registry/ExchangeRegistry.sol";
import {IExchangeRegistry} from "src/interfaces/registry/IExchangeRegistry.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";

contract ExchangeRegistryTest is Test {
    ExchangeRegistry registry;
    address admin = makeAddr("admin");
    address erc721Exchange = makeAddr("erc721Exchange");
    address erc1155Exchange = makeAddr("erc1155Exchange");

    MockERC721 mockERC721;
    MockERC1155 mockERC1155;

    function setUp() public {
        vm.startPrank(admin);
        registry = new ExchangeRegistry(admin);

        // Register exchanges
        registry.registerExchange(IExchangeRegistry.TokenStandard.ERC721, erc721Exchange);
        registry.registerExchange(IExchangeRegistry.TokenStandard.ERC1155, erc1155Exchange);
        vm.stopPrank();

        // Deploy mock NFTs
        mockERC721 = new MockERC721("Test", "TEST");
        mockERC1155 = new MockERC1155("Test", "TEST");
    }

    function test_GetExchange() public {
        address exchange = registry.getExchange(IExchangeRegistry.TokenStandard.ERC721);
        assertEq(exchange, erc721Exchange);
    }

    function test_GetExchangeForERC721Token() public {
        address exchange = registry.getExchangeForToken(address(mockERC721));
        assertEq(exchange, erc721Exchange);
    }

    function test_GetExchangeForERC1155Token() public {
        address exchange = registry.getExchangeForToken(address(mockERC1155));
        assertEq(exchange, erc1155Exchange);
    }

    function test_IsRegisteredExchange() public {
        assertTrue(registry.isRegisteredExchange(erc721Exchange));
        assertTrue(registry.isRegisteredExchange(erc1155Exchange));
        assertFalse(registry.isRegisteredExchange(makeAddr("notRegistered")));
    }

    function test_GetAllExchanges() public {
        (IExchangeRegistry.TokenStandard[] memory standards, address[] memory exchanges) = registry.getAllExchanges();

        assertEq(standards.length, 2);
        assertEq(exchanges.length, 2);
        assertEq(exchanges[0], erc721Exchange);
        assertEq(exchanges[1], erc1155Exchange);
    }

    function test_RevertIf_ExchangeAlreadyRegistered() public {
        vm.prank(admin);
        vm.expectRevert(ExchangeRegistry.ExchangeRegistry__ExchangeAlreadyRegistered.selector);
        registry.registerExchange(IExchangeRegistry.TokenStandard.ERC721, makeAddr("duplicate"));
    }

    function test_RevertIf_UnauthorizedRegister() public {
        vm.prank(makeAddr("notAdmin"));
        vm.expectRevert("Error message");
        registry.registerExchange(IExchangeRegistry.TokenStandard.ERC721, makeAddr("newExchange"));
    }

    function test_UpdateExchange() public {
        address newExchange = makeAddr("newExchange");

        vm.prank(admin);
        registry.updateExchange(IExchangeRegistry.TokenStandard.ERC721, newExchange);

        address updated = registry.getExchange(IExchangeRegistry.TokenStandard.ERC721);
        assertEq(updated, newExchange);
        assertTrue(registry.isRegisteredExchange(newExchange));
        assertFalse(registry.isRegisteredExchange(erc721Exchange));
    }
}
