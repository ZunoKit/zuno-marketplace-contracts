// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IERC1155NFTExchange
 * @notice Interface for ERC1155 NFT Exchange operations
 */
interface IERC1155NFTExchange {
    function listNFT(address contractAddress, uint256 tokenId, uint256 price, uint256 amount, uint256 listingDuration)
        external;

    function buyListedNFT(bytes32 listingId, uint256 amount) external payable;

    function cancelListing(bytes32 listingId) external;

    function updateListingPrice(bytes32 listingId, uint256 newPrice) external;

    function getListing(bytes32 listingId)
        external
        view
        returns (
            address seller,
            address contractAddress,
            uint256 tokenId,
            uint256 price,
            uint256 amount,
            uint256 expirationTime,
            bool isActive
        );
}
