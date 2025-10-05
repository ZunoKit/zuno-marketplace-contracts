// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IEnglishAuction
 * @notice Interface for English Auction operations
 */
interface IEnglishAuction {
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

    function placeBid(bytes32 auctionId) external payable;

    function finalizeAuction(bytes32 auctionId) external;

    function cancelAuction(bytes32 auctionId) external;

    function withdrawRefund(bytes32 auctionId) external;
}
