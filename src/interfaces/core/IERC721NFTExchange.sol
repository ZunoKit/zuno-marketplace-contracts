// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IERC721NFTExchange
 * @notice Interface for ERC721 NFT Exchange operations
 */
interface IERC721NFTExchange {
    function listNFT(address contractAddress, uint256 tokenId, uint256 price, uint256 listingDuration) external;

    function batchListNFT(
        address contractAddress,
        uint256[] memory tokenIds,
        uint256[] memory prices,
        uint256 listingDuration
    ) external;

    function buyListedNFT(bytes32 listingId) external payable;

    function cancelListing(bytes32 listingId) external;

    function updateListingPrice(bytes32 listingId, uint256 newPrice) external;

    function getListing(bytes32 listingId) external view returns (
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 price,
        uint256 expirationTime,
        bool isActive
    );
}
