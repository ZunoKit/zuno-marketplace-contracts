// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IDutchAuction
 * @notice Interface for Dutch Auction operations
 */
interface IDutchAuction {
    enum AuctionType {
        ENGLISH,
        DUTCH
    }

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration,
        AuctionType auctionType,
        address seller
    ) external returns (bytes32 auctionId);

    function createDutchAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration,
        uint256 priceDropPerHour
    ) external returns (bytes32 auctionId);

    function buyNow(bytes32 auctionId) external payable;

    function getCurrentPrice(bytes32 auctionId) external view returns (uint256);

    function cancelAuction(bytes32 auctionId) external;
}
