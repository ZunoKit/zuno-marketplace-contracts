// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IMarketplaceCore
 * @notice Core interface for all marketplace contracts
 * @dev This interface defines the basic functionality that all marketplace contracts should implement
 */
interface IMarketplaceCore {
    /**
     * @notice Returns the version of the marketplace contract
     * @return version The version string
     */
    function version() external pure returns (string memory);

    /**
     * @notice Returns the type of marketplace contract
     * @return contractType The contract type identifier
     */
    function contractType() external pure returns (string memory);

    /**
     * @notice Returns whether this contract is active
     * @return active True if the contract is active
     */
    function isActive() external view returns (bool);
}

/**
 * @title IExchangeCore
 * @notice Core interface for NFT exchange contracts
 * @dev Extends IMarketplaceCore with exchange-specific functionality
 */
interface IExchangeCore is IMarketplaceCore {
    /**
     * @notice Returns the supported NFT standard
     * @return standard The NFT standard (ERC721 or ERC1155)
     */
    function supportedStandard() external pure returns (string memory);

    /**
     * @notice Returns the marketplace wallet address
     * @return wallet The marketplace wallet address
     */
    function marketplaceWallet() external view returns (address);

    /**
     * @notice Returns the taker fee in basis points
     * @return fee The taker fee
     */
    function getTakerFee() external view returns (uint256);

    /**
     * @notice Returns the basis points denominator
     * @return denominator The BPS denominator (usually 10000)
     */
    function BPS_DENOMINATOR() external view returns (uint256);
}

/**
 * @title ICollectionFactory
 * @notice Interface for collection factory contracts
 * @dev Extends IMarketplaceCore with factory-specific functionality
 */
interface ICollectionFactory is IMarketplaceCore {
    /**
     * @notice Returns the total number of collections created
     * @return count The total collection count
     */
    function getTotalCollections() external view returns (uint256);

    /**
     * @notice Returns whether a collection exists at the given address
     * @param collection The collection address to check
     * @return exists True if the collection exists
     */
    function isValidCollection(address collection) external view returns (bool);

    /**
     * @notice Returns the supported collection standards
     * @return standards Array of supported standards
     */
    function getSupportedStandards() external pure returns (string[] memory);
}

/**
 * @title IAuctionFactory
 * @notice Interface for auction factory contracts
 * @dev Extends IMarketplaceCore with auction factory functionality
 */
interface IAuctionFactory is IMarketplaceCore {
    /**
     * @notice Returns the English auction contract address
     * @return auction The English auction address
     */
    function englishAuction() external view returns (address);

    /**
     * @notice Returns the Dutch auction contract address
     * @return auction The Dutch auction address
     */
    function dutchAuction() external view returns (address);

    /**
     * @notice Returns the supported auction types
     * @return types Array of supported auction types
     */
    function getSupportedAuctionTypes() external pure returns (string[] memory);
}

/**
 * @title IMarketplaceValidator
 * @notice Interface for marketplace validator contracts
 * @dev Extends IMarketplaceCore with validation functionality
 */
interface IMarketplaceValidator is IMarketplaceCore {
    /**
     * @notice Validates if an NFT can be listed
     * @param nftContract The NFT contract address
     * @param tokenId The token ID
     * @param seller The seller address
     * @return valid True if the NFT can be listed
     */
    function canList(address nftContract, uint256 tokenId, address seller) external view returns (bool);

    /**
     * @notice Validates if an NFT can be auctioned
     * @param nftContract The NFT contract address
     * @param tokenId The token ID
     * @param seller The seller address
     * @return valid True if the NFT can be auctioned
     */
    function canAuction(address nftContract, uint256 tokenId, address seller) external view returns (bool);
}
