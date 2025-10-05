// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721NFTExchange} from "./ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "./ERC1155NFTExchange.sol";
import "src/errors/NFTExchangeErrors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title NFTExchangeFactory
 * @notice Factory contract for creating and managing NFT exchanges using minimal proxies
 */
contract NFTExchangeFactory is Ownable {
    // Enum for exchange types
    enum ExchangeType {
        ERC721,
        ERC1155
    }

    // Storage optimization: Combine mappings into a struct
    struct ExchangeInfo {
        ExchangeType exchangeType;
        bool isRegistered;
    }

    // Mapping to store exchange info
    mapping(address => ExchangeInfo) public exchanges;
    // Store addresses of exchanges by type for easy removal
    mapping(ExchangeType => address) public exchangeByType;

    // Events
    event ExchangeCreated(address indexed exchangeAddress, ExchangeType exchangeType);
    event ExchangeRemoved(address indexed exchangeAddress);
    event MarketplaceWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event ImplementationUpdated(
        ExchangeType indexed exchangeType, address indexed oldImplementation, address indexed newImplementation
    );

    // Marketplace wallet that can be updated by owner
    address public marketplaceWallet;

    // Implementation contracts for minimal proxies
    mapping(ExchangeType => address) public implementations;

    constructor(address m_marketplaceWallet) Ownable(msg.sender) {
        if (m_marketplaceWallet == address(0)) {
            revert NFTExchange__InvalidMarketplaceWallet();
        }
        marketplaceWallet = m_marketplaceWallet;
    }

    /**
     * @notice Sets the implementation contract for a specific exchange type
     * @param m_exchangeType The type of exchange
     * @param m_implementation The implementation contract address
     */
    function setImplementation(ExchangeType m_exchangeType, address m_implementation) external onlyOwner {
        if (m_implementation == address(0)) {
            revert NFTExchange__InvalidMarketplaceWallet();
        }
        address oldImplementation = implementations[m_exchangeType];
        implementations[m_exchangeType] = m_implementation;
        emit ImplementationUpdated(m_exchangeType, oldImplementation, m_implementation);
    }

    /**
     * @notice Creates a new NFT exchange using minimal proxy
     * @param m_exchangeType The type of exchange to create (ERC721 or ERC1155)
     * @return The address of the newly created exchange
     */
    function createExchange(ExchangeType m_exchangeType) external onlyOwner returns (address) {
        return _createExchangeInternal(m_exchangeType);
    }

    /**
     * @notice Internal function to create exchange with proxy
     * @param m_exchangeType The type of exchange to create
     * @return exchangeAddress Address of created exchange
     */
    function _createExchangeInternal(ExchangeType m_exchangeType) internal returns (address exchangeAddress) {
        // Validate exchange creation
        _validateExchangeCreation(m_exchangeType);

        // Deploy proxy
        exchangeAddress = _deployExchangeProxy(m_exchangeType);

        // Initialize proxy
        _initializeExchange(exchangeAddress, m_exchangeType);

        // Register exchange
        _registerExchange(exchangeAddress, m_exchangeType);

        return exchangeAddress;
    }

    /**
     * @notice Validates exchange creation parameters
     * @param m_exchangeType The type of exchange to validate
     */
    function _validateExchangeCreation(ExchangeType m_exchangeType) internal view {
        // Check if an exchange of this type already exists
        if (exchangeByType[m_exchangeType] != address(0)) {
            revert NFTExchange__ExchangeAlreadyExists();
        }

        // Get implementation address
        address implementation = implementations[m_exchangeType];
        if (implementation == address(0)) {
            revert NFTExchange__InvalidExchangeType();
        }
    }

    /**
     * @notice Deploys a new exchange proxy
     * @param m_exchangeType The type of exchange to deploy
     * @return proxyAddress Address of deployed proxy
     */
    function _deployExchangeProxy(ExchangeType m_exchangeType) internal returns (address proxyAddress) {
        address implementation = implementations[m_exchangeType];
        proxyAddress = Clones.clone(implementation);
    }

    /**
     * @notice Initializes the exchange proxy
     * @param exchangeAddress Address of the proxy
     * @param m_exchangeType Type of exchange
     */
    function _initializeExchange(address exchangeAddress, ExchangeType m_exchangeType) internal {
        if (m_exchangeType == ExchangeType.ERC721) {
            ERC721NFTExchange(exchangeAddress).initialize(marketplaceWallet, owner());
        } else if (m_exchangeType == ExchangeType.ERC1155) {
            ERC1155NFTExchange(exchangeAddress).initialize(marketplaceWallet, owner());
        }
    }

    /**
     * @notice Registers the exchange in factory mappings
     * @param exchangeAddress Address of the exchange
     * @param m_exchangeType Type of exchange
     */
    function _registerExchange(address exchangeAddress, ExchangeType m_exchangeType) internal {
        exchanges[exchangeAddress] = ExchangeInfo({exchangeType: m_exchangeType, isRegistered: true});
        exchangeByType[m_exchangeType] = exchangeAddress;
        emit ExchangeCreated(exchangeAddress, m_exchangeType);
    }

    /**
     * @notice Removes an exchange from the registry
     * @param m_exchangeAddress The address of the exchange to remove
     */
    function removeExchange(address m_exchangeAddress) external onlyOwner {
        ExchangeInfo storage info = exchanges[m_exchangeAddress];
        if (!info.isRegistered) {
            revert NFTExchange__ExchangeDoesNotExist();
        }

        ExchangeType exchangeType = info.exchangeType;
        delete exchanges[m_exchangeAddress];
        delete exchangeByType[exchangeType];
        emit ExchangeRemoved(m_exchangeAddress);
    }

    /**
     * @notice Updates the marketplace wallet address
     * @param m_newMarketplaceWallet The new marketplace wallet address
     */
    function updateMarketplaceWallet(address m_newMarketplaceWallet) external onlyOwner {
        if (m_newMarketplaceWallet == address(0)) {
            revert NFTExchange__InvalidMarketplaceWallet();
        }
        address oldWallet = marketplaceWallet;
        marketplaceWallet = m_newMarketplaceWallet;
        emit MarketplaceWalletUpdated(oldWallet, m_newMarketplaceWallet);
    }

    /**
     * @notice Checks if an address is a valid exchange
     * @param m_exchangeAddress The address to check
     * @return True if the address is a valid exchange, false otherwise
     */
    function isValidExchange(address m_exchangeAddress) external view returns (bool) {
        return exchanges[m_exchangeAddress].isRegistered;
    }

    /**
     * @notice Gets the type of an exchange
     * @param m_exchangeAddress The address of the exchange
     * @return The type of the exchange
     */
    function getExchangeType(address m_exchangeAddress) external view returns (ExchangeType) {
        ExchangeInfo storage info = exchanges[m_exchangeAddress];
        if (!info.isRegistered) {
            revert NFTExchange__ExchangeDoesNotExist();
        }
        return info.exchangeType;
    }

    /**
     * @notice Gets the exchange address by type
     * @param m_exchangeType The type of exchange
     * @return The address of the exchange
     */
    function getExchangeByType(ExchangeType m_exchangeType) external view returns (address) {
        return exchangeByType[m_exchangeType];
    }
}
