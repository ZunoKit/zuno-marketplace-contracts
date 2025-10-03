// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title AuctionErrors
 * @notice Contains all custom errors related to auction functionality
 * @dev Centralized error definitions for better gas efficiency and organization
 */

// ============================================================================
// AUCTION CREATION ERRORS
// ============================================================================

/// @notice Thrown when trying to create an auction with invalid parameters
error Auction__InvalidAuctionParameters();

/// @notice Thrown when auction duration is too short or too long
error Auction__InvalidAuctionDuration();

/// @notice Thrown when start price is zero or invalid
error Auction__InvalidStartPrice();

/// @notice Thrown when reserve price is higher than start price (English auction)
error Auction__InvalidReservePrice();

/// @notice Thrown when trying to auction an NFT the caller doesn't own
error Auction__NotNFTOwner();

/// @notice Thrown when NFT is not approved for auction contract
error Auction__NFTNotApproved();

/// @notice Thrown when trying to create auction for already auctioned NFT
error Auction__NFTAlreadyInAuction();

/// @notice Thrown when trying to auction an NFT that's already listed for sale
error Auction__NFTAlreadyListed();

/// @notice Thrown when NFT is not available for auction/listing
error Auction__NFTNotAvailable();

/// @notice Thrown when auction type is not supported
error Auction__UnsupportedAuctionType();

// ============================================================================
// AUCTION STATE ERRORS
// ============================================================================

/// @notice Thrown when trying to interact with non-existent auction
error Auction__AuctionNotFound();

/// @notice Thrown when trying to interact with inactive auction
error Auction__AuctionNotActive();

/// @notice Thrown when trying to interact with ended auction
error Auction__AuctionEnded();

/// @notice Thrown when trying to interact with cancelled auction
error Auction__AuctionCancelled();

/// @notice Thrown when trying to interact with already settled auction
error Auction__AuctionAlreadySettled();

/// @notice Thrown when auction has not started yet
error Auction__AuctionNotStarted();

/// @notice Thrown when trying to settle auction before it ends
error Auction__AuctionStillActive();

// ============================================================================
// BIDDING ERRORS
// ============================================================================

/// @notice Thrown when bid amount is too low
error Auction__BidTooLow();

/// @notice Thrown when bid increment is insufficient
error Auction__InsufficientBidIncrement();

/// @notice Thrown when seller tries to bid on their own auction
error Auction__SellerCannotBid();

/// @notice Thrown when bidder tries to bid again without outbidding
error Auction__BidderAlreadyHighest();

/// @notice Thrown when bid is placed too late (after auction end)
error Auction__BiddingEnded();

/// @notice Thrown when trying to refund non-existent bid
error Auction__NoBidToRefund();

/// @notice Thrown when bid refund fails
error Auction__RefundFailed();

/// @notice Thrown when insufficient payment is sent
error Auction__InsufficientPayment();

// ============================================================================
// DUTCH AUCTION SPECIFIC ERRORS
// ============================================================================

/// @notice Thrown when trying to calculate price for ended Dutch auction
error Auction__DutchAuctionEnded();

/// @notice Thrown when Dutch auction price calculation fails
error Auction__InvalidPriceCalculation();

/// @notice Thrown when trying to buy at price higher than current
error Auction__PriceAlreadyDecreased();

// ============================================================================
// ACCESS CONTROL ERRORS
// ============================================================================

/// @notice Thrown when caller is not the auction seller
error Auction__NotAuctionSeller();

/// @notice Thrown when caller is not authorized to perform action
error Auction__NotAuthorized();

/// @notice Thrown when trying to perform admin action without permission
error Auction__NotAdmin();

/// @notice Thrown when auction factory is paused
error Auction__FactoryPaused();

// ============================================================================
// SETTLEMENT ERRORS
// ============================================================================

/// @notice Thrown when trying to settle auction without winner
error Auction__NoWinner();

/// @notice Thrown when reserve price not met
error Auction__ReservePriceNotMet();

/// @notice Thrown when NFT transfer fails during settlement
error Auction__NFTTransferFailed();

/// @notice Thrown when payment distribution fails
error Auction__PaymentDistributionFailed();

/// @notice Thrown when trying to settle already settled auction
error Auction__AlreadySettled();

// ============================================================================
// CANCELLATION ERRORS
// ============================================================================

/// @notice Thrown when trying to cancel auction with active bids
error Auction__CannotCancelWithBids();

/// @notice Thrown when trying to cancel auction too late
error Auction__CancellationTooLate();

/// @notice Thrown when auction cannot be cancelled in current state
error Auction__CannotCancel();

// ============================================================================
// GENERAL ERRORS
// ============================================================================

/// @notice Thrown when zero address is provided where not allowed
error Auction__ZeroAddress();

/// @notice Thrown when array lengths don't match
error Auction__ArrayLengthMismatch();

/// @notice Thrown when contract is in invalid state
error Auction__InvalidState();

/// @notice Thrown when operation would cause integer overflow
error Auction__Overflow();

/// @notice Thrown when operation would cause integer underflow
error Auction__Underflow();

/// @notice Thrown when reentrancy is detected
error Auction__ReentrancyDetected();

/// @notice Thrown when contract call fails
error Auction__CallFailed();

/// @notice Thrown when invalid signature is provided
error Auction__InvalidSignature();
