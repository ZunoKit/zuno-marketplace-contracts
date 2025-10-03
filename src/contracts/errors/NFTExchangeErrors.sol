// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Base NFT Exchange Errors
error NFTExchange__InvalidMarketplaceWallet();
error NFTExchange__NFTNotActive();
error NFTExchange__ListingExpired();
error NFTExchange__InsufficientPayment();
error NFTExchange__TransferToSellerFailed();
error NFTExchange__TransferToCreatorFailed();
error NFTExchange__TransferToMarketplaceFailed();
error NFTExchange__RefundFailed();
error NFTExchange__InvalidTakerFee();

// ERC721 NFT Exchange Errors
error NFTExchange__NotTheOwner();
error NFTExchange__MarketplaceNotApproved();
error NFTExchange__PriceMustBeGreaterThanZero();
error NFTExchange__DurationMustBeGreaterThanZero();
error NFTExchange__ArrayLengthMismatch();
error NFTExchange__NFTAlreadyListed();

// ERC1155 NFT Exchange Errors
error NFTExchange__InsufficientBalance();
error NFTExchange__AmountMustBeGreaterThanZero();

// Factory Errors
error NFTExchange__ExchangeAlreadyExists();
error NFTExchange__InvalidExchangeType();
error NFTExchange__ExchangeDoesNotExist();

// Unified Exchange Errors
error NFTExchange__UnsupportedTokenType();
error NFTExchange__UnsupportedNFTType();

// Offer Manager Errors
error NFTExchange__InvalidOwner();
error NFTExchange__InvalidCollection();
error NFTExchange__InvalidPrice();
error NFTExchange__InvalidDuration();
error NFTExchange__InvalidListing();
error NFTExchange__InvalidQuantity();
error NFTExchange__InvalidParameters();
