// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IExchangeRegistry} from "../interfaces/registry/IExchangeRegistry.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ExchangeRegistry
 * @notice Central registry for managing exchange contracts across different token standards
 * @dev Automatically detects token standards and routes to appropriate exchange
 */
contract ExchangeRegistry is IExchangeRegistry, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping from token standard to exchange address
    mapping(TokenStandard => address) private s_exchanges;

    // Mapping to check if address is a registered exchange
    mapping(address => bool) private s_isExchange;

    // Mapping from listing ID to exchange address
    mapping(bytes32 => address) private s_listingToExchange;

    // Array to track all registered standards
    TokenStandard[] private s_registeredStandards;

    error ExchangeRegistry__ZeroAddress();
    error ExchangeRegistry__ExchangeAlreadyRegistered();
    error ExchangeRegistry__ExchangeNotRegistered();
    error ExchangeRegistry__UnsupportedTokenStandard();
    error ExchangeRegistry__InvalidTokenContract();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function getExchange(TokenStandard standard) external view override returns (address) {
        address exchange = s_exchanges[standard];
        if (exchange == address(0)) revert ExchangeRegistry__ExchangeNotRegistered();
        return exchange;
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function getExchangeForToken(address nftContract) public view override returns (address) {
        if (nftContract == address(0)) revert ExchangeRegistry__ZeroAddress();

        // Check if contract supports IERC165
        try IERC165(nftContract).supportsInterface(type(IERC165).interfaceId) returns (bool supported) {
            if (!supported) revert ExchangeRegistry__InvalidTokenContract();
        } catch {
            revert ExchangeRegistry__InvalidTokenContract();
        }

        // Check for ERC721
        try IERC165(nftContract).supportsInterface(type(IERC721).interfaceId) returns (bool isERC721) {
            if (isERC721) {
                address exchange = s_exchanges[TokenStandard.ERC721];
                if (exchange == address(0)) revert ExchangeRegistry__ExchangeNotRegistered();
                return exchange;
            }
        } catch {}

        // Check for ERC1155
        try IERC165(nftContract).supportsInterface(type(IERC1155).interfaceId) returns (bool isERC1155) {
            if (isERC1155) {
                address exchange = s_exchanges[TokenStandard.ERC1155];
                if (exchange == address(0)) revert ExchangeRegistry__ExchangeNotRegistered();
                return exchange;
            }
        } catch {}

        // If we get here, the token standard is not supported
        revert ExchangeRegistry__UnsupportedTokenStandard();
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function getExchangeForListing(bytes32 listingId) external view override returns (address) {
        address exchange = s_listingToExchange[listingId];
        if (exchange == address(0)) revert ExchangeRegistry__ExchangeNotRegistered();
        return exchange;
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function registerExchange(TokenStandard standard, address exchange) external override onlyRole(ADMIN_ROLE) {
        if (exchange == address(0)) revert ExchangeRegistry__ZeroAddress();
        if (s_exchanges[standard] != address(0)) revert ExchangeRegistry__ExchangeAlreadyRegistered();

        s_exchanges[standard] = exchange;
        s_isExchange[exchange] = true;
        s_registeredStandards.push(standard);

        emit ExchangeRegistered(standard, exchange);
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function updateExchange(TokenStandard standard, address newExchange) external override onlyRole(ADMIN_ROLE) {
        if (newExchange == address(0)) revert ExchangeRegistry__ZeroAddress();

        address oldExchange = s_exchanges[standard];
        if (oldExchange == address(0)) revert ExchangeRegistry__ExchangeNotRegistered();

        s_isExchange[oldExchange] = false;
        s_exchanges[standard] = newExchange;
        s_isExchange[newExchange] = true;

        emit ExchangeUpdated(standard, oldExchange, newExchange);
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function isRegisteredExchange(address exchange) external view override returns (bool) {
        return s_isExchange[exchange];
    }

    /**
     * @inheritdoc IExchangeRegistry
     */
    function getAllExchanges()
        external
        view
        override
        returns (TokenStandard[] memory standards, address[] memory exchanges)
    {
        uint256 length = s_registeredStandards.length;
        standards = new TokenStandard[](length);
        exchanges = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            standards[i] = s_registeredStandards[i];
            exchanges[i] = s_exchanges[s_registeredStandards[i]];
        }

        return (standards, exchanges);
    }

    /**
     * @notice Register a listing with its exchange
     * @dev Called by exchange contracts when a listing is created
     * @param listingId The listing ID
     * @param exchange The exchange address
     */
    function registerListing(bytes32 listingId, address exchange) external {
        if (!s_isExchange[msg.sender]) revert ExchangeRegistry__ExchangeNotRegistered();
        s_listingToExchange[listingId] = exchange;
    }
}
