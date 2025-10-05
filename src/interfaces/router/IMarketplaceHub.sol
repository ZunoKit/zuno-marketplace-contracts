// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFeeRegistry} from "../registry/IFeeRegistry.sol";

/**
 * @title IMarketplaceHub
 * @notice Interface for MarketplaceHub - simplified address discovery
 */
interface IMarketplaceHub {
    // Address discovery
    function getExchangeFor(address nftContract) external view returns (address);

    function getERC721Exchange() external view returns (address);

    function getERC1155Exchange() external view returns (address);

    function getCollectionFactory(string memory tokenType) external view returns (address);

    function getEnglishAuction() external view returns (address);

    function getDutchAuction() external view returns (address);

    function getAuctionFactory() external view returns (address);

    // Fee queries
    function calculateFees(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (IFeeRegistry.FeeBreakdown memory breakdown);

    function getPlatformFeePercentage() external view returns (uint256);

    // Collection verification
    function verifyCollection(address collection) external view returns (bool isValid, string memory tokenType);

    // Registry access
    function getExchangeRegistry() external view returns (address);

    function getCollectionRegistry() external view returns (address);

    function getFeeRegistry() external view returns (address);

    function getAuctionRegistry() external view returns (address);

    // Batch queries
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
        );
}
