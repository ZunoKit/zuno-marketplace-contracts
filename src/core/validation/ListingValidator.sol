// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "src/core/access/MarketplaceAccessControl.sol";
import {Listing} from "src/types/ListingTypes.sol";
import "src/errors/NFTExchangeErrors.sol";
import "src/events/NFTExchangeEvents.sol";

/**
 * @title ListingValidator
 * @notice Advanced validation rules for marketplace listings
 * @dev Provides comprehensive validation for listing creation and updates
 * @author NFT Marketplace Team
 */
contract ListingValidator is Ownable, ReentrancyGuard, Pausable {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Access control contract
    MarketplaceAccessControl public accessControl;

    /// @notice Global validation settings
    ValidationSettings public globalSettings;

    /// @notice Collection-specific validation overrides
    mapping(address => ValidationSettings) public collectionSettings;

    /// @notice User cooldown tracking
    mapping(address => UserCooldown) public userCooldowns;

    /// @notice Listing quality scores
    mapping(bytes32 => uint256) public listingQualityScores;

    /// @notice Anti-spam tracking
    mapping(address => SpamTracker) public spamTrackers;

    /// @notice Total validated listings
    uint256 public totalValidatedListings;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Validation settings for listings
     */
    struct ValidationSettings {
        uint256 minPrice; // Minimum listing price
        uint256 maxPrice; // Maximum listing price
        uint256 minDuration; // Minimum listing duration (seconds)
        uint256 maxDuration; // Maximum listing duration (seconds)
        uint256 cooldownPeriod; // Cooldown between listings (seconds)
        uint256 maxListingsPerUser; // Maximum active listings per user
        bool requireVerifiedCollection; // Whether collection must be verified
        bool enableQualityCheck; // Whether to perform quality checks
        bool isActive; // Whether these settings are active
    }

    /**
     * @notice User cooldown tracking
     */
    struct UserCooldown {
        uint256 lastListingTime; // Last time user created a listing
        uint256 activeListings; // Number of active listings
        uint256 totalListings; // Total listings created
        bool isRestricted; // Whether user is restricted
    }

    /**
     * @notice Anti-spam tracking
     */
    struct SpamTracker {
        uint256 listingsInLastHour; // Listings created in last hour
        uint256 lastHourStart; // Start of current hour window
        uint256 suspiciousActivity; // Suspicious activity score
        bool isFlagged; // Whether user is flagged for spam
    }

    /**
     * @notice Validation result
     */
    struct ValidationResult {
        bool isValid; // Whether listing passes validation
        string[] errors; // Array of validation errors
        uint256 qualityScore; // Quality score (0-100)
        uint256 recommendedPrice; // Recommended price (if applicable)
    }

    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Maximum quality score
    uint256 public constant MAX_QUALITY_SCORE = 100;

    /// @notice Minimum quality score for auto-approval
    uint256 public constant MIN_AUTO_APPROVAL_SCORE = 70;

    /// @notice Maximum listings per hour for spam detection
    uint256 public constant MAX_LISTINGS_PER_HOUR = 10;

    /// @notice Default cooldown period (5 minutes)
    uint256 public constant DEFAULT_COOLDOWN = 300;

    // ============================================================================
    // EVENTS
    // ============================================================================

    event ValidationSettingsUpdated(address indexed collection, ValidationSettings settings, address updatedBy);

    event ListingValidated(bytes32 indexed listingId, address indexed user, bool isValid, uint256 qualityScore);

    event UserRestricted(address indexed user, string reason, uint256 restrictionEnd);

    event SpamDetected(address indexed user, uint256 suspiciousActivity, string reason);

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Ensures caller has required role
     */
    modifier onlyRole(bytes32 role) {
        if (!accessControl.hasRole(role, msg.sender)) {
            revert NFTExchange__InvalidOwner();
        }
        _;
    }

    /**
     * @notice Validates collection address
     */
    modifier validCollection(address collection) {
        if (collection == address(0)) {
            revert NFTExchange__InvalidCollection();
        }
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the ListingValidator
     * @param _accessControl Address of the access control contract
     */
    constructor(address _accessControl) Ownable(msg.sender) {
        if (_accessControl == address(0)) {
            revert NFTExchange__InvalidOwner();
        }

        accessControl = MarketplaceAccessControl(_accessControl);

        // Initialize default global settings
        globalSettings = ValidationSettings({
            minPrice: 0.001 ether, // 0.001 ETH minimum
            maxPrice: 1000 ether, // 1000 ETH maximum
            minDuration: 1 hours, // 1 hour minimum
            maxDuration: 30 days, // 30 days maximum
            cooldownPeriod: DEFAULT_COOLDOWN,
            maxListingsPerUser: 100,
            requireVerifiedCollection: false,
            enableQualityCheck: true,
            isActive: true
        });
    }

    // ============================================================================
    // VALIDATION FUNCTIONS
    // ============================================================================

    /**
     * @notice Validates a listing before creation
     * @param listing Listing data to validate
     * @param user User creating the listing
     * @return result Validation result
     */
    function validateListing(Listing calldata listing, address user)
        external
        view
        returns (ValidationResult memory result)
    {
        result.errors = new string[](0);
        result.isValid = true;
        result.qualityScore = MAX_QUALITY_SCORE;

        // Get validation settings
        ValidationSettings memory settings = _getValidationSettings(listing.nftContract);

        if (!settings.isActive) {
            result.isValid = true;
            return result;
        }

        // Validate price range
        if (!_validatePriceRange(listing.price, settings)) {
            result.errors = _addError(result.errors, "Price outside allowed range");
            result.isValid = false;
            result.qualityScore -= 20;
        }

        // Validate duration
        if (!_validateDuration(listing.endTime - block.timestamp, settings)) {
            result.errors = _addError(result.errors, "Duration outside allowed range");
            result.isValid = false;
            result.qualityScore -= 15;
        }

        // Check user cooldown
        if (!_checkCooldown(user, settings)) {
            result.errors = _addError(result.errors, "User in cooldown period");
            result.isValid = false;
            result.qualityScore -= 25;
        }

        // Check user listing limits
        if (!_checkUserLimits(user, settings)) {
            result.errors = _addError(result.errors, "User exceeds listing limits");
            result.isValid = false;
            result.qualityScore -= 30;
        }

        // Check for spam
        if (_isSpamListing(user)) {
            result.errors = _addError(result.errors, "Potential spam detected");
            result.isValid = false;
            result.qualityScore -= 40;
        }

        // Quality checks
        if (settings.enableQualityCheck) {
            uint256 qualityDeduction = _performQualityCheck(listing);
            result.qualityScore = result.qualityScore > qualityDeduction ? result.qualityScore - qualityDeduction : 0;
        }

        return result;
    }

    /**
     * @notice Validates a listing update
     * @param oldListing Original listing
     * @param newListing Updated listing
     * @param user User updating the listing
     * @return isValid Whether update is valid
     */
    function validateListingUpdate(Listing calldata oldListing, Listing calldata newListing, address user)
        external
        view
        returns (bool isValid)
    {
        // Basic validation
        if (oldListing.seller != user) {
            return false;
        }

        if (oldListing.nftContract != newListing.nftContract || oldListing.tokenId != newListing.tokenId) {
            return false;
        }

        // Get validation settings
        ValidationSettings memory settings = _getValidationSettings(newListing.nftContract);

        // Validate new price
        if (!_validatePriceRange(newListing.price, settings)) {
            return false;
        }

        // Validate new duration
        if (!_validateDuration(newListing.endTime - block.timestamp, settings)) {
            return false;
        }

        return true;
    }

    // ============================================================================
    // ADMIN FUNCTIONS
    // ============================================================================

    /**
     * @notice Sets validation settings for a collection
     * @param collection Collection address
     * @param settings Validation settings
     */
    function setValidationSettings(address collection, ValidationSettings calldata settings)
        external
        onlyOwner
        validCollection(collection)
    {
        collectionSettings[collection] = settings;

        emit ValidationSettingsUpdated(collection, settings, msg.sender);
    }

    /**
     * @notice Sets global validation settings
     * @param settings Global validation settings
     */
    function setGlobalValidationSettings(ValidationSettings calldata settings) external onlyOwner {
        globalSettings = settings;

        emit ValidationSettingsUpdated(address(0), settings, msg.sender);
    }

    /**
     * @notice Pauses the contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================================================
    // INTERNAL VALIDATION FUNCTIONS
    // ============================================================================

    /**
     * @notice Validates price range
     */
    function _validatePriceRange(uint256 price, ValidationSettings memory settings) internal pure returns (bool) {
        return price >= settings.minPrice && price <= settings.maxPrice;
    }

    /**
     * @notice Validates listing duration
     */
    function _validateDuration(uint256 duration, ValidationSettings memory settings) internal pure returns (bool) {
        return duration >= settings.minDuration && duration <= settings.maxDuration;
    }

    /**
     * @notice Checks user cooldown period
     */
    function _checkCooldown(address user, ValidationSettings memory settings) internal view returns (bool) {
        UserCooldown memory cooldown = userCooldowns[user];

        if (cooldown.isRestricted) {
            return false;
        }

        // If user has never listed before (lastListingTime == 0), allow listing
        if (cooldown.lastListingTime == 0) {
            return true;
        }

        return block.timestamp >= cooldown.lastListingTime + settings.cooldownPeriod;
    }

    /**
     * @notice Checks user listing limits
     */
    function _checkUserLimits(address user, ValidationSettings memory settings) internal view returns (bool) {
        UserCooldown memory cooldown = userCooldowns[user];
        return cooldown.activeListings < settings.maxListingsPerUser;
    }

    /**
     * @notice Checks for spam patterns
     */
    function _isSpamListing(address user) internal view returns (bool) {
        SpamTracker memory tracker = spamTrackers[user];

        if (tracker.isFlagged) {
            return true;
        }

        // Check listings in last hour
        if (block.timestamp < tracker.lastHourStart + 1 hours) {
            return tracker.listingsInLastHour >= MAX_LISTINGS_PER_HOUR;
        }

        return false;
    }

    /**
     * @notice Performs quality check on listing
     */
    function _performQualityCheck(Listing calldata listing) internal view returns (uint256 qualityDeduction) {
        qualityDeduction = 0;

        // Check for suspicious pricing
        if (listing.price < 0.0001 ether) {
            qualityDeduction += 15; // Very low price
        }

        // Check listing duration
        uint256 duration = listing.endTime - block.timestamp;
        if (duration < 1 hours) {
            qualityDeduction += 10; // Very short duration
        } else if (duration > 90 days) {
            qualityDeduction += 5; // Very long duration
        }

        return qualityDeduction;
    }

    /**
     * @notice Gets validation settings for a collection
     */
    function _getValidationSettings(address collection) internal view returns (ValidationSettings memory) {
        ValidationSettings memory collectionSetting = collectionSettings[collection];

        if (collectionSetting.isActive) {
            return collectionSetting;
        }

        return globalSettings;
    }

    /**
     * @notice Adds error to error array
     */
    function _addError(string[] memory errors, string memory newError) internal pure returns (string[] memory) {
        string[] memory newErrors = new string[](errors.length + 1);

        for (uint256 i = 0; i < errors.length; i++) {
            newErrors[i] = errors[i];
        }

        newErrors[errors.length] = newError;
        return newErrors;
    }
}
