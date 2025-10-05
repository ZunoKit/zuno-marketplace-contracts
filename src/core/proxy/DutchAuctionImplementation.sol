// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DutchAuction} from "../auction/DutchAuction.sol";

/**
 * @title DutchAuctionImplementation
 * @notice Implementation contract for Dutch auctions using proxy pattern
 * @dev This contract is deployed once and used as implementation for all Dutch auction proxies
 * @author NFT Marketplace Team
 */
contract DutchAuctionImplementation is DutchAuction {
    /// @notice Flag to track if contract has been initialized
    bool private _initialized;

    /**
     * @notice Constructor that prevents direct usage
     * @dev This ensures the implementation contract cannot be used directly
     */
    constructor() DutchAuction(address(0xdead)) {
        _initialized = true; // Prevent initialization of implementation
    }

    /**
     * @notice Initializes the Dutch auction implementation
     * @param _marketplaceWallet Address to receive marketplace fees
     * @dev This function replaces the constructor for proxy pattern
     */
    function initialize(address _marketplaceWallet) external {
        require(!_initialized, "Already initialized");
        require(_marketplaceWallet != address(0), "Zero address");

        _initialized = true;
        marketplaceWallet = _marketplaceWallet;

        // Set factory contract
        factoryContract = msg.sender;

        // Initialize marketplace fee to default value (2%)
        marketplaceFee = 200;

        // Initialize auction duration limits to default values
        minAuctionDuration = DEFAULT_MIN_DURATION;
        maxAuctionDuration = DEFAULT_MAX_DURATION;

        // Transfer ownership to factory
        _transferOwnership(msg.sender);
    }
}
