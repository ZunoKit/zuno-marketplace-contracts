// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

// Core Events
event NFTListed(
    bytes32 indexed listingId, address indexed contractAddress, uint256 indexed tokenId, address seller, uint256 price
);

event NFTSold(
    bytes32 indexed listingId,
    address indexed contractAddress,
    uint256 indexed tokenId,
    address seller,
    address buyer,
    uint256 price
);

event ListingCancelled(
    bytes32 indexed listingId, address indexed contractAddress, uint256 indexed tokenId, address seller
);

event MarketplaceWalletUpdated(address indexed oldWallet, address indexed newWallet);

event TakerFeeUpdated(uint256 oldFee, uint256 newFee);

// Collection Events
event CollectionCreated(
    address indexed collectionAddress,
    address indexed creator,
    string name,
    string symbol,
    uint256 indexed collectionType
);

event CollectionVerified(address indexed collectionAddress);

event CollectionUnverified(address indexed collectionAddress);

// Auction Events
event AuctionCreated(
    bytes32 indexed auctionId,
    address indexed contractAddress,
    uint256 indexed tokenId,
    address seller,
    uint256 startingPrice,
    uint256 duration
);

event AuctionBid(bytes32 indexed auctionId, address indexed bidder, uint256 amount);

event AuctionFinalized(bytes32 indexed auctionId, address indexed winner, uint256 finalPrice);

event AuctionCancelled(bytes32 indexed auctionId, address indexed seller);
