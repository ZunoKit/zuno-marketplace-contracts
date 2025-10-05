// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IExchangeRegistry} from "../interfaces/registry/IExchangeRegistry.sol";
import {ICollectionRegistry} from "../interfaces/registry/ICollectionRegistry.sol";
import {IFeeRegistry} from "../interfaces/registry/IFeeRegistry.sol";
import {IAuctionRegistry} from "../interfaces/registry/IAuctionRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MarketplaceHub
 * @notice Simplified single entry point - provides contract addresses and basic queries
 * @dev Frontend only needs this ONE address to discover all other contracts
 *
 * Philosophy: Keep it simple! This contract does NOT wrap function calls.
 * Instead, it helps frontend discover the right contract addresses to call directly.
 *
 * Benefits:
 * - Minimal gas overhead (just address lookups)
 * - Easy to maintain and upgrade
 * - Frontend still calls actual contracts (better for debugging)
 * - No complex routing logic to maintain
 */
contract MarketplaceHub is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IExchangeRegistry public exchangeRegistry;
    ICollectionRegistry public collectionRegistry;
    IFeeRegistry public feeRegistry;
    IAuctionRegistry public auctionRegistry;

    error MarketplaceHub__ZeroAddress();
    error MarketplaceHub__InvalidRegistry();

    event RegistryUpdated(string registryType, address indexed newRegistry);

    constructor(
        address admin,
        address _exchangeRegistry,
        address _collectionRegistry,
        address _feeRegistry,
        address _auctionRegistry
    ) {
        if (
            _exchangeRegistry == address(0) || _collectionRegistry == address(0) || _feeRegistry == address(0)
                || _auctionRegistry == address(0)
        ) {
            revert MarketplaceHub__ZeroAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        exchangeRegistry = IExchangeRegistry(_exchangeRegistry);
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        feeRegistry = IFeeRegistry(_feeRegistry);
        auctionRegistry = IAuctionRegistry(_auctionRegistry);
    }

    // ==================== ADDRESS DISCOVERY ====================

    /**
     * @notice Get the exchange contract address for a specific NFT
     * @param nftContract The NFT contract address
     * @return The exchange contract to use for this NFT
     */
    function getExchangeFor(address nftContract) external view returns (address) {
        return exchangeRegistry.getExchangeForToken(nftContract);
    }

    /**
     * @notice Get ERC721 Exchange address
     */
    function getERC721Exchange() external view returns (address) {
        return exchangeRegistry.getExchange(IExchangeRegistry.TokenStandard.ERC721);
    }

    /**
     * @notice Get ERC1155 Exchange address
     */
    function getERC1155Exchange() external view returns (address) {
        return exchangeRegistry.getExchange(IExchangeRegistry.TokenStandard.ERC1155);
    }

    /**
     * @notice Get factory address for token type
     * @param tokenType "ERC721" or "ERC1155"
     */
    function getCollectionFactory(string memory tokenType) external view returns (address) {
        return collectionRegistry.getFactory(tokenType);
    }

    /**
     * @notice Get English Auction contract address
     */
    function getEnglishAuction() external view returns (address) {
        return auctionRegistry.getAuctionContract(IAuctionRegistry.AuctionType.ENGLISH);
    }

    /**
     * @notice Get Dutch Auction contract address
     */
    function getDutchAuction() external view returns (address) {
        return auctionRegistry.getAuctionContract(IAuctionRegistry.AuctionType.DUTCH);
    }

    /**
     * @notice Get Auction Factory address
     */
    function getAuctionFactory() external view returns (address) {
        return auctionRegistry.getAuctionFactory();
    }

    // ==================== FEE QUERIES ====================

    /**
     * @notice Calculate fees for a sale
     * @param nftContract The NFT contract
     * @param tokenId The token ID
     * @param salePrice The sale price
     * @return breakdown Complete fee breakdown
     */
    function calculateFees(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (IFeeRegistry.FeeBreakdown memory breakdown)
    {
        return feeRegistry.calculateAllFees(nftContract, tokenId, salePrice);
    }

    /**
     * @notice Get platform fee percentage
     */
    function getPlatformFeePercentage() external view returns (uint256) {
        return feeRegistry.getPlatformFeePercentage();
    }

    // ==================== COLLECTION VERIFICATION ====================

    /**
     * @notice Verify if a collection is valid
     * @param collection The collection address
     * @return isValid Whether collection is verified
     * @return tokenType The token type ("ERC721" or "ERC1155")
     */
    function verifyCollection(address collection) external view returns (bool isValid, string memory tokenType) {
        return collectionRegistry.verifyCollection(collection);
    }

    // ==================== REGISTRY ACCESS ====================

    function getExchangeRegistry() external view returns (address) {
        return address(exchangeRegistry);
    }

    function getCollectionRegistry() external view returns (address) {
        return address(collectionRegistry);
    }

    function getFeeRegistry() external view returns (address) {
        return address(feeRegistry);
    }

    function getAuctionRegistry() external view returns (address) {
        return address(auctionRegistry);
    }

    // ==================== BATCH QUERIES ====================

    /**
     * @notice Get all contract addresses in one call
     * @dev Useful for frontend initialization
     */
    function getAllAddresses()
        external
        view
        returns (
            address erc721Exchange,
            address erc1155Exchange,
            address erc721Factory,
            address erc1155Factory,
            address englishAuction,
            address dutchAuction,
            address auctionFactory,
            address feeRegistryAddr
        )
    {
        erc721Exchange = exchangeRegistry.getExchange(IExchangeRegistry.TokenStandard.ERC721);
        erc1155Exchange = exchangeRegistry.getExchange(IExchangeRegistry.TokenStandard.ERC1155);
        erc721Factory = collectionRegistry.getFactory("ERC721");
        erc1155Factory = collectionRegistry.getFactory("ERC1155");
        englishAuction = auctionRegistry.getAuctionContract(IAuctionRegistry.AuctionType.ENGLISH);
        dutchAuction = auctionRegistry.getAuctionContract(IAuctionRegistry.AuctionType.DUTCH);
        auctionFactory = auctionRegistry.getAuctionFactory();
        feeRegistryAddr = address(feeRegistry);
    }

    // ==================== ADMIN ====================

    /**
     * @notice Update a registry address
     * @param registryType "exchange", "collection", "fee", or "auction"
     * @param newRegistry The new registry address
     */
    function updateRegistry(string memory registryType, address newRegistry) external onlyRole(ADMIN_ROLE) {
        if (newRegistry == address(0)) revert MarketplaceHub__ZeroAddress();

        bytes32 typeHash = keccak256(bytes(registryType));

        if (typeHash == keccak256(bytes("exchange"))) {
            exchangeRegistry = IExchangeRegistry(newRegistry);
        } else if (typeHash == keccak256(bytes("collection"))) {
            collectionRegistry = ICollectionRegistry(newRegistry);
        } else if (typeHash == keccak256(bytes("fee"))) {
            feeRegistry = IFeeRegistry(newRegistry);
        } else if (typeHash == keccak256(bytes("auction"))) {
            auctionRegistry = IAuctionRegistry(newRegistry);
        } else {
            revert MarketplaceHub__InvalidRegistry();
        }

        emit RegistryUpdated(registryType, newRegistry);
    }
}
