// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/contracts/interfaces/IMarketplaceValidator.sol";
import "src/contracts/errors/MarketplaceValidatorErrors.sol";

/**
 * @title MarketplaceValidator
 * @notice Central validator for cross-validation between auction and marketplace systems
 * @dev This contract tracks NFT status across the entire marketplace ecosystem
 *      to prevent conflicts between listings and auctions
 */
contract MarketplaceValidator is IMarketplaceValidator, Ownable, ReentrancyGuard {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Mapping from NFT contract => tokenId => owner => status
    mapping(address => mapping(uint256 => mapping(address => NFTStatus))) private nftStatus;

    /// @notice Mapping from NFT contract => tokenId => owner => listing/auction ID
    mapping(address => mapping(uint256 => mapping(address => bytes32))) private nftIdentifier;

    /// @notice Mapping of registered exchange contracts
    mapping(address => bool) public registeredExchanges;

    /// @notice Mapping of registered auction contracts
    mapping(address => bool) public registeredAuctions;

    /// @notice Array of all registered exchanges
    address[] public allExchanges;

    /// @notice Array of all registered auctions
    address[] public allAuctions;

    /// @notice Emergency manager contract address
    address public emergencyManager;

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Ensures caller is a registered exchange or auction contract
     */
    modifier onlyRegisteredContract() {
        if (!registeredExchanges[msg.sender] && !registeredAuctions[msg.sender]) {
            revert MarketplaceValidator__NotRegisteredContract();
        }
        _;
    }

    /**
     * @notice Ensures NFT is available for listing/auction
     */
    modifier onlyAvailableNFT(address nftContract, uint256 tokenId, address owner) {
        NFTStatus status = nftStatus[nftContract][tokenId][owner];
        if (status != NFTStatus.AVAILABLE && status != NFTStatus.CANCELLED) {
            revert MarketplaceValidator__NFTNotAvailable();
        }
        _;
    }

    /**
     * @notice Ensures caller is owner or emergency manager
     */
    modifier onlyOwnerOrEmergencyManager() {
        if (msg.sender != owner() && msg.sender != emergencyManager) {
            revert MarketplaceValidator__NotAuthorized();
        }
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor() Ownable(msg.sender) {}

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function isNFTAvailable(address nftContract, uint256 tokenId, address owner)
        external
        view
        override
        returns (bool isAvailable, NFTStatus currentStatus)
    {
        currentStatus = nftStatus[nftContract][tokenId][owner];
        isAvailable = (currentStatus == NFTStatus.AVAILABLE || currentStatus == NFTStatus.CANCELLED);
        return (isAvailable, currentStatus);
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function isNFTListed(address nftContract, uint256 tokenId, address owner)
        external
        view
        override
        returns (bool isListed)
    {
        return nftStatus[nftContract][tokenId][owner] == NFTStatus.LISTED;
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function isNFTInAuction(address nftContract, uint256 tokenId, address owner)
        external
        view
        override
        returns (bool inAuction)
    {
        return nftStatus[nftContract][tokenId][owner] == NFTStatus.IN_AUCTION;
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function getNFTStatus(address nftContract, uint256 tokenId, address owner)
        external
        view
        override
        returns (NFTStatus status)
    {
        return nftStatus[nftContract][tokenId][owner];
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function isRegisteredExchange(address exchangeAddress) external view override returns (bool isRegistered) {
        return registeredExchanges[exchangeAddress];
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function isRegisteredAuction(address auctionAddress) external view override returns (bool isRegistered) {
        return registeredAuctions[auctionAddress];
    }

    // ============================================================================
    // STATE MANAGEMENT FUNCTIONS
    // ============================================================================

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function setNFTListed(address nftContract, uint256 tokenId, address owner, bytes32 listingId)
        external
        override
        onlyRegisteredContract
        nonReentrant
        onlyAvailableNFT(nftContract, tokenId, owner)
    {
        NFTStatus oldStatus = nftStatus[nftContract][tokenId][owner];
        nftStatus[nftContract][tokenId][owner] = NFTStatus.LISTED;
        nftIdentifier[nftContract][tokenId][owner] = listingId;

        emit NFTStatusChanged(nftContract, tokenId, owner, oldStatus, NFTStatus.LISTED);
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function setNFTInAuction(address nftContract, uint256 tokenId, address owner, bytes32 auctionId)
        external
        override
        onlyRegisteredContract
        nonReentrant
        onlyAvailableNFT(nftContract, tokenId, owner)
    {
        NFTStatus oldStatus = nftStatus[nftContract][tokenId][owner];
        nftStatus[nftContract][tokenId][owner] = NFTStatus.IN_AUCTION;
        nftIdentifier[nftContract][tokenId][owner] = auctionId;

        emit NFTStatusChanged(nftContract, tokenId, owner, oldStatus, NFTStatus.IN_AUCTION);
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function setNFTAvailable(address nftContract, uint256 tokenId, address owner)
        external
        override
        onlyRegisteredContract
        nonReentrant
    {
        NFTStatus oldStatus = nftStatus[nftContract][tokenId][owner];
        nftStatus[nftContract][tokenId][owner] = NFTStatus.AVAILABLE;
        delete nftIdentifier[nftContract][tokenId][owner];

        emit NFTStatusChanged(nftContract, tokenId, owner, oldStatus, NFTStatus.AVAILABLE);
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function setNFTSold(address nftContract, uint256 tokenId, address oldOwner, address newOwner)
        external
        override
        onlyRegisteredContract
        nonReentrant
    {
        NFTStatus oldStatus = nftStatus[nftContract][tokenId][oldOwner];

        // Clear old owner's status
        nftStatus[nftContract][tokenId][oldOwner] = NFTStatus.SOLD;
        delete nftIdentifier[nftContract][tokenId][oldOwner];

        // Set new owner as available
        nftStatus[nftContract][tokenId][newOwner] = NFTStatus.AVAILABLE;

        emit NFTStatusChanged(nftContract, tokenId, oldOwner, oldStatus, NFTStatus.SOLD);

        emit NFTStatusChanged(nftContract, tokenId, newOwner, NFTStatus.SOLD, NFTStatus.AVAILABLE);
    }

    // ============================================================================
    // ADMIN FUNCTIONS
    // ============================================================================

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function registerExchange(address exchangeAddress, uint8 exchangeType) external override onlyOwner {
        if (exchangeAddress == address(0)) {
            revert MarketplaceValidator__ZeroAddress();
        }
        if (registeredExchanges[exchangeAddress]) {
            revert MarketplaceValidator__AlreadyRegistered();
        }

        registeredExchanges[exchangeAddress] = true;
        allExchanges.push(exchangeAddress);

        emit ExchangeRegistered(exchangeAddress, exchangeType);
    }

    /**
     * @inheritdoc IMarketplaceValidator
     */
    function registerAuction(address auctionAddress, uint8 auctionType) external override onlyOwner {
        if (auctionAddress == address(0)) {
            revert MarketplaceValidator__ZeroAddress();
        }
        if (registeredAuctions[auctionAddress]) {
            revert MarketplaceValidator__AlreadyRegistered();
        }

        registeredAuctions[auctionAddress] = true;
        allAuctions.push(auctionAddress);

        emit AuctionRegistered(auctionAddress, auctionType);
    }

    /**
     * @notice Gets all registered exchanges
     * @return exchanges Array of exchange addresses
     */
    function getAllExchanges() external view returns (address[] memory exchanges) {
        return allExchanges;
    }

    /**
     * @notice Gets all registered auctions
     * @return auctions Array of auction addresses
     */
    function getAllAuctions() external view returns (address[] memory auctions) {
        return allAuctions;
    }

    /**
     * @notice Sets the emergency manager contract address
     * @param _emergencyManager Address of the emergency manager contract
     */
    function setEmergencyManager(address _emergencyManager) external onlyOwner {
        if (_emergencyManager == address(0)) {
            revert MarketplaceValidator__ZeroAddress();
        }
        emergencyManager = _emergencyManager;
        emit EmergencyManagerSet(_emergencyManager);
    }

    /**
     * @notice Emergency function to reset NFT status (admin or emergency manager only)
     * @param nftContract Address of the NFT contract
     * @param tokenId Token ID
     * @param owner Owner of the NFT
     */
    function emergencyResetNFTStatus(address nftContract, uint256 tokenId, address owner)
        external
        onlyOwnerOrEmergencyManager
    {
        NFTStatus oldStatus = nftStatus[nftContract][tokenId][owner];
        nftStatus[nftContract][tokenId][owner] = NFTStatus.AVAILABLE;
        delete nftIdentifier[nftContract][tokenId][owner];

        emit NFTStatusChanged(nftContract, tokenId, owner, oldStatus, NFTStatus.AVAILABLE);
    }
}
