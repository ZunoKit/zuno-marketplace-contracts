// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CollectionParams} from "src/types/ListingTypes.sol";
import {ERC721CollectionCreated, ERC1155CollectionCreated} from "src/events/CollectionEvents.sol";
import {ICollectionFactory} from "src/interfaces/IMarketplaceCore.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ERC721CollectionFactory} from "./ERC721CollectionFactory.sol";
import {ERC1155CollectionFactory} from "./ERC1155CollectionFactory.sol";

/**
 * @title CollectionFactoryRegistry
 * @notice Unified registry that routes collection creation to appropriate factories
 * @dev Provides same interface as original CollectionFactory for frontend compatibility
 */
contract CollectionFactoryRegistry is ERC165, ICollectionFactory {
    ERC721CollectionFactory public immutable erc721Factory;
    ERC1155CollectionFactory public immutable erc1155Factory;

    // Track all collections across both factories
    mapping(address => bool) private s_validCollections;
    uint256 private s_totalCollections;

    event FactoriesSet(address erc721Factory, address erc1155Factory);

    constructor(address _erc721Factory, address _erc1155Factory) {
        erc721Factory = ERC721CollectionFactory(_erc721Factory);
        erc1155Factory = ERC1155CollectionFactory(_erc1155Factory);

        emit FactoriesSet(_erc721Factory, _erc1155Factory);
    }

    /**
     * @notice Creates a new ERC721 collection via the ERC721 factory
     * @param params Collection parameters
     * @return The address of the created collection
     */
    function createERC721Collection(CollectionParams memory params) external returns (address) {
        address collectionAddr = erc721Factory.createERC721Collection(params);

        // Track in registry
        s_validCollections[collectionAddr] = true;
        s_totalCollections++;

        // Re-emit event for consistency
        emit ERC721CollectionCreated(collectionAddr, msg.sender);
        return collectionAddr;
    }

    /**
     * @notice Creates a new ERC1155 collection via the ERC1155 factory
     * @param params Collection parameters
     * @return The address of the created collection
     */
    function createERC1155Collection(CollectionParams memory params) external returns (address) {
        address collectionAddr = erc1155Factory.createERC1155Collection(params);

        // Track in registry
        s_validCollections[collectionAddr] = true;
        s_totalCollections++;

        // Re-emit event for consistency
        emit ERC1155CollectionCreated(collectionAddr, msg.sender);
        return collectionAddr;
    }

    // ============ IMarketplaceCore Implementation ============

    function version() public pure override returns (string memory) {
        return "1.0.0";
    }

    function contractType() public pure override returns (string memory) {
        return "CollectionFactoryRegistry";
    }

    function isActive() public pure override returns (bool) {
        return true;
    }

    // ============ ICollectionFactory Implementation ============

    function getTotalCollections() external view override returns (uint256) {
        return s_totalCollections;
    }

    function isValidCollection(address collection) external view override returns (bool) {
        // Check registry first, then check individual factories as fallback
        if (s_validCollections[collection]) {
            return true;
        }

        return erc721Factory.isValidCollection(collection) || erc1155Factory.isValidCollection(collection);
    }

    function getSupportedStandards() external pure override returns (string[] memory) {
        string[] memory standards = new string[](2);
        standards[0] = "ERC721";
        standards[1] = "ERC1155";
        return standards;
    }

    // ============ Additional Registry Functions ============

    /**
     * @notice Get the addresses of the underlying factories
     * @return erc721FactoryAddr Address of ERC721 factory
     * @return erc1155FactoryAddr Address of ERC1155 factory
     */
    function getFactoryAddresses() external view returns (address erc721FactoryAddr, address erc1155FactoryAddr) {
        return (address(erc721Factory), address(erc1155Factory));
    }

    /**
     * @notice Get total collections from individual factories
     * @return erc721Count Total ERC721 collections
     * @return erc1155Count Total ERC1155 collections
     */
    function getFactoryCollectionCounts() external view returns (uint256 erc721Count, uint256 erc1155Count) {
        return (erc721Factory.getTotalCollections(), erc1155Factory.getTotalCollections());
    }

    // ============ ERC165 Implementation ============

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ICollectionFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
