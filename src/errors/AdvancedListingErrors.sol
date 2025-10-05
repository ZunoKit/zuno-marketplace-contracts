// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title AdvancedListingErrors
 * @notice Custom errors for Advanced Listing system
 * @dev Using custom errors instead of require strings for gas optimization
 */

// ============================================================================
// GENERAL ERRORS
// ============================================================================

/// @notice Thrown when a zero address is provided where not allowed
error AdvancedListing__ZeroAddress();

/// @notice Thrown when array lengths don't match in batch operations
error AdvancedListing__ArrayLengthMismatch();

/// @notice Thrown when an empty array is provided
error AdvancedListing__EmptyArray();

/// @notice Thrown when caller doesn't have sufficient permissions
error AdvancedListing__InsufficientPermissions();

/// @notice Thrown when an invalid parameter is provided
error AdvancedListing__InvalidParameter();

/// @notice Thrown when contract is paused
error AdvancedListing__ContractPaused();

/// @notice Thrown when operation is not allowed in current state
error AdvancedListing__InvalidState();

// ============================================================================
// LISTING ERRORS
// ============================================================================

/// @notice Thrown when listing ID doesn't exist
error AdvancedListing__ListingNotFound();

/// @notice Thrown when listing is not active
error AdvancedListing__ListingNotActive();

/// @notice Thrown when listing has expired
error AdvancedListing__ListingExpired();

/// @notice Thrown when listing is already sold
error AdvancedListing__ListingAlreadySold();

/// @notice Thrown when listing is cancelled
error AdvancedListing__ListingCancelled();

/// @notice Thrown when trying to operate on own listing
error AdvancedListing__CannotBuyOwnListing();

/// @notice Thrown when caller is not the seller
error AdvancedListing__NotSeller();

/// @notice Thrown when listing type is not supported
error AdvancedListing__UnsupportedListingType();

/// @notice Thrown when listing duration is invalid
error AdvancedListing__InvalidDuration();

/// @notice Thrown when listing price is invalid
error AdvancedListing__InvalidPrice();

/// @notice Thrown when listing start time is invalid
error AdvancedListing__InvalidStartTime();

/// @notice Thrown when listing has not started yet
error AdvancedListing__ListingNotStarted();

/// @notice Thrown when trying to create duplicate listing
error AdvancedListing__DuplicateListing();

/// @notice Thrown when listing limit is exceeded
error AdvancedListing__ListingLimitExceeded();

// ============================================================================
// NFT ERRORS
// ============================================================================

/// @notice Thrown when NFT contract is not supported
error AdvancedListing__UnsupportedNFTContract();

/// @notice Thrown when token doesn't exist
error AdvancedListing__TokenNotFound();

/// @notice Thrown when caller doesn't own the NFT
error AdvancedListing__NotTokenOwner();

/// @notice Thrown when NFT is not approved for transfer
error AdvancedListing__NotApproved();

/// @notice Thrown when insufficient NFT quantity
error AdvancedListing__InsufficientQuantity();

/// @notice Thrown when NFT is already listed
error AdvancedListing__TokenAlreadyListed();

/// @notice Thrown when NFT transfer fails
error AdvancedListing__TransferFailed();

/// @notice Thrown when NFT is locked or frozen
error AdvancedListing__TokenLocked();

// ============================================================================
// PAYMENT ERRORS
// ============================================================================

/// @notice Thrown when insufficient payment provided
error AdvancedListing__InsufficientPayment();

/// @notice Thrown when payment amount is incorrect
error AdvancedListing__IncorrectPayment();

/// @notice Thrown when payment transfer fails
error AdvancedListing__PaymentFailed();

/// @notice Thrown when refund fails
error AdvancedListing__RefundFailed();

/// @notice Thrown when fee calculation fails
error AdvancedListing__FeeCalculationFailed();

/// @notice Thrown when fee is too high
error AdvancedListing__FeeTooHigh();

/// @notice Thrown when royalty calculation fails
error AdvancedListing__RoyaltyCalculationFailed();

// ============================================================================
// AUCTION ERRORS
// ============================================================================

/// @notice Thrown when auction has not started
error AdvancedListing__AuctionNotStarted();

/// @notice Thrown when auction has ended
error AdvancedListing__AuctionEnded();

/// @notice Thrown when bid is too low
error AdvancedListing__BidTooLow();

/// @notice Thrown when bid increment is insufficient
error AdvancedListing__InsufficientBidIncrement();

/// @notice Thrown when reserve price not met
error AdvancedListing__ReservePriceNotMet();

/// @notice Thrown when auction cannot be cancelled (has bids)
error AdvancedListing__CannotCancelAuctionWithBids();

/// @notice Thrown when trying to bid on own auction
error AdvancedListing__CannotBidOnOwnAuction();

/// @notice Thrown when auction parameters are invalid
error AdvancedListing__InvalidAuctionParams();

/// @notice Thrown when auction extension fails
error AdvancedListing__AuctionExtensionFailed();

// ============================================================================
// OFFER ERRORS
// ============================================================================

/// @notice Thrown when offer doesn't exist
error AdvancedListing__OfferNotFound();

/// @notice Thrown when offer is not active
error AdvancedListing__OfferNotActive();

/// @notice Thrown when offer has expired
error AdvancedListing__OfferExpired();

/// @notice Thrown when offer amount is too low
error AdvancedListing__OfferTooLow();

/// @notice Thrown when caller is not the offer maker
error AdvancedListing__NotOfferMaker();

/// @notice Thrown when offers are not accepted for this listing
error AdvancedListing__OffersNotAccepted();

/// @notice Thrown when trying to make offer on own listing
error AdvancedListing__CannotOfferOnOwnListing();

/// @notice Thrown when offer already exists
error AdvancedListing__OfferAlreadyExists();

/// @notice Thrown when offer limit is exceeded
error AdvancedListing__OfferLimitExceeded();

/// @notice Thrown when offer validity period is invalid
error AdvancedListing__InvalidOfferValidity();

// ============================================================================
// BUNDLE ERRORS
// ============================================================================

/// @notice Thrown when bundle doesn't exist
error AdvancedListing__BundleNotFound();

/// @notice Thrown when bundle is empty
error AdvancedListing__EmptyBundle();

/// @notice Thrown when bundle has too many items
error AdvancedListing__BundleTooLarge();

/// @notice Thrown when bundle item is invalid
error AdvancedListing__InvalidBundleItem();

/// @notice Thrown when bundle price is invalid
error AdvancedListing__InvalidBundlePrice();

/// @notice Thrown when caller is not bundle creator
error AdvancedListing__NotBundleCreator();

/// @notice Thrown when bundle contains duplicate items
error AdvancedListing__DuplicateBundleItem();

/// @notice Thrown when bundle item is not owned by creator
error AdvancedListing__BundleItemNotOwned();

/// @notice Thrown when bundle type is not supported
error AdvancedListing__UnsupportedBundleType();

// ============================================================================
// TIME ERRORS
// ============================================================================

/// @notice Thrown when operation is performed outside allowed time window
error AdvancedListing__OutsideTimeWindow();

/// @notice Thrown when time constraint is violated
error AdvancedListing__TimeConstraintViolated();

/// @notice Thrown when deadline has passed
error AdvancedListing__DeadlinePassed();

/// @notice Thrown when cooldown period is active
error AdvancedListing__CooldownActive();

/// @notice Thrown when time parameters are invalid
error AdvancedListing__InvalidTimeParams();

// ============================================================================
// ACCESS CONTROL ERRORS
// ============================================================================

/// @notice Thrown when caller doesn't have required role
error AdvancedListing__MissingRole();

/// @notice Thrown when operation requires admin privileges
error AdvancedListing__AdminRequired();

/// @notice Thrown when operation requires moderator privileges
error AdvancedListing__ModeratorRequired();

/// @notice Thrown when user is blacklisted
error AdvancedListing__UserBlacklisted();

/// @notice Thrown when contract is blacklisted
error AdvancedListing__ContractBlacklisted();

/// @notice Thrown when operation is restricted
error AdvancedListing__OperationRestricted();

// ============================================================================
// VALIDATION ERRORS
// ============================================================================

/// @notice Thrown when signature is invalid
error AdvancedListing__InvalidSignature();

/// @notice Thrown when nonce is invalid or already used
error AdvancedListing__InvalidNonce();

/// @notice Thrown when data validation fails
error AdvancedListing__ValidationFailed();

/// @notice Thrown when checksum doesn't match
error AdvancedListing__ChecksumMismatch();

/// @notice Thrown when format is invalid
error AdvancedListing__InvalidFormat();

// ============================================================================
// LIMIT ERRORS
// ============================================================================

/// @notice Thrown when rate limit is exceeded
error AdvancedListing__RateLimitExceeded();

/// @notice Thrown when daily limit is exceeded
error AdvancedListing__DailyLimitExceeded();

/// @notice Thrown when maximum listings per user exceeded
error AdvancedListing__MaxListingsExceeded();

/// @notice Thrown when maximum offers per user exceeded
error AdvancedListing__MaxOffersExceeded();

/// @notice Thrown when maximum bundles per user exceeded
error AdvancedListing__MaxBundlesExceeded();

// ============================================================================
// EMERGENCY ERRORS
// ============================================================================

/// @notice Thrown when emergency stop is active
error AdvancedListing__EmergencyStop();

/// @notice Thrown when emergency action is not allowed
error AdvancedListing__EmergencyActionNotAllowed();

/// @notice Thrown when emergency cooldown is active
error AdvancedListing__EmergencyCooldownActive();

// ============================================================================
// INTEGRATION ERRORS
// ============================================================================

/// @notice Thrown when external contract call fails
error AdvancedListing__ExternalCallFailed();

/// @notice Thrown when oracle price is stale
error AdvancedListing__StalePriceData();

/// @notice Thrown when price feed is unavailable
error AdvancedListing__PriceFeedUnavailable();

/// @notice Thrown when validator contract rejects operation
error AdvancedListing__ValidatorRejected();

/// @notice Thrown when fee contract is not set
error AdvancedListing__FeeContractNotSet();

// ============================================================================
// DUTCH AUCTION ERRORS
// ============================================================================

/// @notice Thrown when Dutch auction price parameters are invalid
error AdvancedListing__InvalidDutchAuctionParams();

/// @notice Thrown when Dutch auction has reached minimum price
error AdvancedListing__MinimumPriceReached();

/// @notice Thrown when Dutch auction price calculation fails
error AdvancedListing__PriceCalculationFailed();

// ============================================================================
// COLLECTION OFFER ERRORS
// ============================================================================

/// @notice Thrown when collection offer parameters are invalid
error AdvancedListing__InvalidCollectionOfferParams();

/// @notice Thrown when trait requirements are not met
error AdvancedListing__TraitRequirementsNotMet();

/// @notice Thrown when collection offer limit exceeded
error AdvancedListing__CollectionOfferLimitExceeded();

// ============================================================================
// METADATA ERRORS
// ============================================================================

/// @notice Thrown when metadata is invalid or corrupted
error AdvancedListing__InvalidMetadata();

/// @notice Thrown when metadata size exceeds limit
error AdvancedListing__MetadataTooLarge();

/// @notice Thrown when required metadata is missing
error AdvancedListing__MissingMetadata();
