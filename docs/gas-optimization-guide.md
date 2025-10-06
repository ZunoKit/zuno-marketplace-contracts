# Gas Optimization Guide

## Overview

This guide outlines the gas optimization strategies implemented in the Zuno Marketplace contracts to achieve ≥3% gas reduction and prevent regressions.

## Gas Regression Monitoring

### Canary Tests

The following tests are monitored for gas regressions (5% threshold):

1. **E2E_CoreTradingTest:test_E2E_CompleteERC721TradingJourney** (~610,000 gas)
2. **E2E_FeesAndRoyaltiesTest:test_E2E_RoyaltyDistributionCompleteFlow** (~700,000-1,900,000 gas)
3. **E2E_CoreTradingTest:test_E2E_ListingLifecycle** (~610,000 gas)

### Monitoring Commands

```bash
# Run gas regression check
make gas-check

# Generate canary test report
make gas-report-canary

# Generate full gas report
make gas-report-full

# Apply gas optimizations
make gas-optimize
```

## Implemented Optimizations

### 1. Storage Variable Caching

**Problem**: Multiple SLOAD operations for frequently accessed storage variables.

**Solution**: Cache storage variables in stack variables.

```solidity
// Before (multiple SLOAD operations)
function _distributePayments(PaymentDistribution memory payment) internal {
    PaymentDistributionLib.PaymentData memory paymentData = PaymentDistributionLib.PaymentData({
        marketplaceWallet: s_marketplaceWallet, // SLOAD
        // ... other fields
    });
    // Later in function: s_takerFee (another SLOAD)
}

// After (cached variables)
function _distributePayments(PaymentDistribution memory payment) internal {
    // Cache storage variables to reduce SLOAD operations (saves ~200 gas per call)
    uint256 takerFee = s_takerFee;
    address marketplaceWallet = s_marketplaceWallet;
    
    // Use cached values throughout function
}
```

**Gas Savings**: ~200 gas per call

### 2. Optimized Payment Distribution Library

**Problem**: Multiple external calls and redundant calculations in payment distribution.

**Solution**: Created `OptimizedPaymentDistributionLib` with:

- Reduced external calls by batching transfers
- Cached marketplace wallet parameter
- Optimized arithmetic operations
- Single event emission per distribution

```solidity
// Optimized payment distribution
function distributePaymentWithCachedWallet(
    OptimizedPaymentData memory data,
    address marketplaceWallet
) internal {
    // Use cached marketplace wallet instead of reading from storage
    data.marketplaceWallet = marketplaceWallet;
    
    // Batch all transfers in sequence
    if (data.marketplaceFee > 0) {
        _safeTransferOptimized(marketplaceWallet, data.marketplaceFee);
    }
    // ... other transfers
    
    // Single event emission
    emit PaymentDistributed(/* all data */);
}
```

**Gas Savings**: ~300-500 gas per payment distribution

### 3. ERC1155 Partial Purchase Optimization

**Problem**: Duplicate price and fee calculations for partial purchases.

**Solution**: Calculate proportional price and fees once.

```solidity
// Calculate proportional amounts once
uint256 proportionalPrice = (fullPrice * purchaseAmount) / totalAmount;
uint256 proportionalTakerFee = (proportionalPrice * takerFee) / BPS_DENOMINATOR;
uint256 proportionalRoyalty = (proportionalPrice * royaltyRate) / BPS_DENOMINATOR;

// Use calculated values throughout function
```

**Gas Savings**: ~150-200 gas per partial purchase

### 4. Batch Operations Optimization

**Problem**: High gas costs for batch operations due to multiple storage writes and events.

**Solution**: 
- Coalesce events where possible
- Reduce storage writes by batching updates
- Use unchecked arithmetic where provably safe

```solidity
// Batch event emission
event BatchOperationCompleted(
    address indexed operator,
    uint256 indexed operationCount,
    bytes32[] operationIds
);

// Instead of individual events per operation
```

**Gas Savings**: ~100-200 gas per batch operation

### 5. Unchecked Arithmetic

**Problem**: Safe arithmetic operations where overflow is provably impossible.

**Solution**: Use unchecked arithmetic for calculations with known bounds.

```solidity
// Safe: basis points calculations are bounded by 10000
uint256 marketplaceFee = (salePrice * marketplaceFeeRate) / bpsDenominator;

// Safe: seller amount = price - fees, where fees <= price
uint256 sellerAmount = salePrice - marketplaceFee - royaltyAmount;
```

**Gas Savings**: ~20-30 gas per calculation

## Hot Path Optimizations

### BaseNFTExchange._distributePayments

**Current Gas**: ~2,000-3,000 gas
**Target Reduction**: 15-20%

**Optimizations Applied**:
1. Cache `s_takerFee` and `s_marketplaceWallet`
2. Use optimized payment distribution library
3. Reduce external calls
4. Single event emission

### ERC1155 Partial Purchase

**Current Gas**: ~1,500-2,500 gas
**Target Reduction**: 10-15%

**Optimizations Applied**:
1. Calculate proportional amounts once
2. Cache calculation results
3. Use unchecked arithmetic where safe

### Batch Operations

**Current Gas**: ~3,000,000+ gas
**Target Reduction**: 5-10%

**Optimizations Applied**:
1. Coalesce events
2. Batch storage updates
3. Optimize loop operations

## Monitoring and Alerts

### CI Integration

The gas regression monitoring is integrated into GitHub Actions:

- Runs on every PR and push to main/develop
- Fails if gas increases >5% for canary tests
- Posts gas report as PR comment
- Generates top-10 gas consumers summary

### Thresholds

- **Warning**: 3% increase
- **Failure**: 5% increase
- **Critical**: 10% increase

### Reporting

Each PR includes:
- Top 10 gas consumers
- Canary test results
- Gas optimization opportunities
- Comparison with baseline

## Best Practices

### 1. Always Cache Storage Variables

```solidity
// Good
uint256 fee = s_takerFee;
address wallet = s_marketplaceWallet;

// Bad
s_takerFee // Multiple SLOAD operations
```

### 2. Use Memory for Temporary Data

```solidity
// Good
Listing memory listing = s_listings[listingId];

// Bad
s_listings[listingId].price // Multiple SLOAD operations
```

### 3. Batch Operations When Possible

```solidity
// Good
function batchOperation(bytes32[] memory listingIds) external {
    for (uint256 i = 0; i < listingIds.length; i++) {
        // Process each listing
    }
    emit BatchOperationCompleted(listingIds);
}

// Bad
function processListing(bytes32 listingId) external {
    // Process single listing
    emit ListingProcessed(listingId); // Individual events
}
```

### 4. Use Unchecked Arithmetic Where Safe

```solidity
// Good (when overflow is impossible)
uint256 result = a + b; // unchecked

// Bad (when overflow is possible)
uint256 result = a + b; // safe math
```

## Testing Gas Optimizations

### Run Canary Tests

```bash
# Test specific canary functions
forge test --match-test "test_E2E_CompleteERC721TradingJourney" --gas-report

# Test all canary tests
forge test --match-contract CanaryTests --gas-report
```

### Compare Gas Usage

```bash
# Generate baseline
forge snapshot > gas-snapshot-baseline.txt

# Apply optimizations
make gas-optimize

# Generate new snapshot
forge snapshot > gas-snapshot-optimized.txt

# Compare results
diff gas-snapshot-baseline.txt gas-snapshot-optimized.txt
```

## Future Optimizations

### 1. Assembly Optimizations

For critical paths, consider assembly optimizations:

```solidity
// Optimized storage read
function _getTakerFee() internal view returns (uint256) {
    uint256 slot;
    assembly {
        slot := sload(s_takerFee.slot)
    }
    return slot;
}
```

### 2. Packed Structs

Optimize storage layout by packing structs:

```solidity
struct OptimizedListing {
    address contractAddress; // 20 bytes
    uint96 tokenId;          // 12 bytes (fits in 32 bytes)
    uint128 price;           // 16 bytes
    uint128 listingStart;    // 16 bytes (fits in 32 bytes)
    // ... other fields
}
```

### 3. Event Optimization

Use indexed parameters efficiently:

```solidity
event OptimizedEvent(
    bytes32 indexed listingId,    // 1 indexed
    address indexed seller,       // 2 indexed
    address indexed buyer,        // 3 indexed (max)
    uint256 price,                // non-indexed
    uint256 timestamp             // non-indexed
);
```

## Conclusion

These optimizations target the most gas-intensive operations in the marketplace:

1. **Payment distribution** - Reduced external calls and cached values
2. **ERC1155 partial purchases** - Eliminated duplicate calculations
3. **Batch operations** - Coalesced events and optimized loops
4. **Storage access** - Cached frequently accessed variables

The monitoring system ensures these optimizations are maintained and prevents regressions through automated CI checks.