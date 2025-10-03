// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IExchange {
    // Events
    event NFTListed(bytes32 indexed listingId, address contractAddress, uint256 tokenId, uint256 price, address seller);
    event NFTSold(
        bytes32 indexed listingId,
        address contractAddress,
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price
    );
    event ListingCancelled(bytes32 indexed listingId, address contractAddress, uint256 tokenId, address seller);
    event MarketplaceWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event TakerFeeUpdated(uint256 oldFee, uint256 newFee);

    // Listing functions
    function listNFT(address contractAddress, uint256 tokenId, uint256 amount, uint256 price, uint256 duration)
        external;
    function batchListNFT(
        address contractAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        uint256[] calldata prices,
        uint256 duration
    ) external;
    function cancelListing(bytes32 listingId) external;
    function batchCancelListing(bytes32[] calldata listingIds) external;

    // Buy functions
    function buyNFT(bytes32 listingId) external payable;
    function batchBuyNFT(bytes32[] calldata listingIds) external payable;

    // View functions
    function getListing(bytes32 listingId)
        external
        view
        returns (
            address contractAddress,
            uint256 tokenId,
            uint256 price,
            address seller,
            uint256 duration,
            uint256 start,
            uint256 status,
            uint256 amount
        );
    function getGeneratedListingId(address contractAddress, uint256 tokenId, address seller)
        external
        view
        returns (bytes32);
    function getListingsByCollection(address contractAddress) external view returns (bytes32[] memory);
    function getListingsBySeller(address seller) external view returns (bytes32[] memory);
    function getBuyerSeesPrice(bytes32 listingId) external view returns (uint256);
    function marketplaceWallet() external view returns (address);
    function takerFee() external view returns (uint256);
    function BPS_DENOMINATOR() external view returns (uint256);

    // Admin functions
    function updateMarketplaceWallet(address newWallet) external;
    function updateTakerFee(uint256 newFee) external;
}
