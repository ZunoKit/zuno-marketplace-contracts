// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721NFTExchange} from "./ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "./ERC1155NFTExchange.sol";
import {NFTExchangeFactory} from "../factory/NFTExchangeFactory.sol";
import {BaseNFTExchange} from "src/common/BaseNFTExchange.sol";
import {IExchangeCore} from "src/interfaces/IMarketplaceCore.sol";
import {Constants} from "src/common/Constants.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "src/errors/NFTExchangeErrors.sol";
import "src/events/NFTExchangeEvents.sol";

/**
 * @title NFTExchangeRegistry
 * @notice Unified registry that routes exchange operations to appropriate exchanges
 * @dev Frontend only needs this contract address - it handles everything automatically
 */
contract NFTExchangeRegistry is ERC165, IExchangeCore, Ownable, IERC1155Receiver {
    NFTExchangeFactory public immutable factory;

    // Cache exchange addresses for gas optimization
    ERC721NFTExchange public erc721Exchange;
    ERC1155NFTExchange public erc1155Exchange;

    // Track all listings across both exchanges
    mapping(bytes32 => address) private s_listingToExchange;
    mapping(bytes32 => address) private s_realOwners; // Track real NFT owners
    uint256 private s_totalListings;

    // Struct to avoid stack too deep
    struct ListingData {
        address contractAddress;
        uint256 tokenId;
        uint256 price;
        address seller;
        uint256 duration;
        uint256 start;
        uint256 status;
        uint256 amount;
    }

    event ExchangesSet(address erc721Exchange, address erc1155Exchange);
    event ListingRouted(bytes32 indexed listingId, address indexed exchange, string nftType);

    constructor(address _factory) Ownable(msg.sender) {
        if (_factory == address(0)) {
            revert NFTExchange__InvalidMarketplaceWallet();
        }
        factory = NFTExchangeFactory(_factory);

        // Initialize exchange addresses from factory
        _updateExchangeAddresses();
    }

    /**
     * @notice Updates exchange addresses from factory
     * @dev Called automatically in constructor and can be called manually if exchanges change
     */
    function updateExchangeAddresses() external onlyOwner {
        _updateExchangeAddresses();
    }

    /**
     * @notice Internal function to update exchange addresses from factory
     */
    function _updateExchangeAddresses() internal {
        address erc721Addr = factory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721);
        address erc1155Addr = factory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC1155);

        if (erc721Addr != address(0)) {
            erc721Exchange = ERC721NFTExchange(erc721Addr);
        }
        if (erc1155Addr != address(0)) {
            erc1155Exchange = ERC1155NFTExchange(erc1155Addr);
        }

        emit ExchangesSet(erc721Addr, erc1155Addr);
    }

    // ============================================================================
    // GETTER FUNCTIONS - Frontend only needs these
    // ============================================================================

    /**
     * @notice Get factory address (for advanced users)
     */
    function getFactory() external view returns (address) {
        return address(factory);
    }

    /**
     * @notice Get current exchange addresses
     */
    function getCurrentExchanges() external view returns (address erc721, address erc1155) {
        return (address(erc721Exchange), address(erc1155Exchange));
    }

    /**
     * @notice Check if exchanges are properly initialized
     */
    function areExchangesInitialized() external view returns (bool) {
        return address(erc721Exchange) != address(0) && address(erc1155Exchange) != address(0);
    }

    // ============================================================================
    // UNIFIED LISTING FUNCTIONS
    // ============================================================================

    /**
     * @notice Lists an NFT (auto-detects ERC721 vs ERC1155)
     * @param contractAddress NFT contract address
     * @param tokenId Token ID
     * @param amount Amount (1 for ERC721, >1 for ERC1155)
     * @param price Price in wei
     * @param duration Listing duration in seconds
     */
    function listNFT(address contractAddress, uint256 tokenId, uint256 amount, uint256 price, uint256 duration)
        external
    {
        // Validate input parameters
        _validateListingParams(contractAddress, amount, price, duration);

        // Route to appropriate exchange
        if (_isERC721(contractAddress)) {
            _listERC721NFT(contractAddress, tokenId, price, duration);
        } else if (_isERC1155(contractAddress)) {
            _listERC1155NFT(contractAddress, tokenId, amount, price, duration);
        } else {
            revert NFTExchange__UnsupportedNFTType();
        }
    }

    /**
     * @notice Internal function to validate listing parameters
     */
    function _validateListingParams(address contractAddress, uint256 amount, uint256 price, uint256 duration)
        internal
        view
    {
        require(contractAddress != address(0), "Invalid contract address");
        require(Constants.isValidPrice(price), "Price too low");
        require(Constants.isValidListingDuration(duration), "Invalid duration");

        // Specific validation for ERC721 vs ERC1155
        if (_isERC721(contractAddress)) {
            require(amount == 1, "ERC721 amount must be 1");
        } else if (_isERC1155(contractAddress)) {
            require(amount > 0, "ERC1155 amount must be > 0");
        }
    }

    /**
     * @notice Internal function to list ERC721 NFT
     */
    function _listERC721NFT(address contractAddress, uint256 tokenId, uint256 price, uint256 duration) internal {
        // 1. Transfer NFT from user to Registry
        IERC721(contractAddress).transferFrom(msg.sender, address(this), tokenId);

        // 2. Approve Exchange to transfer NFT
        IERC721(contractAddress).approve(address(erc721Exchange), tokenId);

        // 3. List NFT on Exchange (Registry as seller)
        erc721Exchange.listNFT(contractAddress, tokenId, price, duration);

        // 4. Register listing and track real owner
        bytes32 listingId = erc721Exchange.getGeneratedListingId(contractAddress, tokenId, address(this));
        _registerListing(listingId, contractAddress, tokenId, address(erc721Exchange), msg.sender, "ERC721");
    }

    /**
     * @notice Internal function to list ERC1155 NFT
     */
    function _listERC1155NFT(address contractAddress, uint256 tokenId, uint256 amount, uint256 price, uint256 duration)
        internal
    {
        // 1. Transfer NFT from user to Registry
        IERC1155(contractAddress).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        // 2. Approve Exchange to transfer NFT
        IERC1155(contractAddress).setApprovalForAll(address(erc1155Exchange), true);

        // 3. List NFT on Exchange (Registry as seller)
        erc1155Exchange.listNFT(contractAddress, tokenId, amount, price, duration);

        // 4. Register listing and track real owner
        bytes32 listingId = erc1155Exchange.getGeneratedListingId(contractAddress, tokenId, address(this));
        _registerListing(listingId, contractAddress, tokenId, address(erc1155Exchange), msg.sender, "ERC1155");
    }

    /**
     * @notice Internal function to register listing and emit event
     */
    function _registerListing(
        bytes32 listingId,
        address, /* contractAddress */
        uint256, /* tokenId */
        address exchange,
        address realOwner,
        string memory nftType
    ) internal {
        // Store the mapping from listing to exchange
        s_listingToExchange[listingId] = exchange;

        // Store the real owner (the user who created the listing)
        s_realOwners[listingId] = realOwner;

        // Increment total listings counter
        s_totalListings++;

        emit ListingRouted(listingId, exchange, nftType);
    }

    /**
     * @notice Cancel a listing (auto-routes to correct exchange)
     */
    function cancelListing(bytes32 listingId) external {
        // Only real owner can cancel
        require(s_realOwners[listingId] == msg.sender, "Not listing owner");

        address exchange = s_listingToExchange[listingId];
        require(exchange != address(0), "Listing not found");

        // Cancel on the appropriate exchange
        if (exchange == address(erc721Exchange)) {
            erc721Exchange.cancelListing(listingId);
        } else if (exchange == address(erc1155Exchange)) {
            erc1155Exchange.cancelListing(listingId);
        }

        // Clean up mappings
        delete s_listingToExchange[listingId];
        delete s_realOwners[listingId];
        s_totalListings--;
    }

    /**
     * @notice Buy an NFT (auto-routes to correct exchange)
     */
    function buyNFT(bytes32 listingId) external payable {
        address exchange = s_listingToExchange[listingId];
        require(exchange != address(0), "Listing not found");

        // Buy from the appropriate exchange
        if (exchange == address(erc721Exchange)) {
            erc721Exchange.buyNFT{value: msg.value}(listingId);
        } else if (exchange == address(erc1155Exchange)) {
            erc1155Exchange.buyNFT{value: msg.value}(listingId);
        }

        // Clean up mappings after successful purchase
        delete s_listingToExchange[listingId];
        delete s_realOwners[listingId];
        s_totalListings--;
    }

    // ============================================================================
    // UNIFIED VIEW FUNCTIONS
    // ============================================================================

    /**
     * @notice Get listing details (auto-routes to correct exchange)
     */
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
        )
    {
        ListingData memory data = _getListingData(listingId);
        return (
            data.contractAddress,
            data.tokenId,
            data.price,
            data.seller,
            data.duration,
            data.start,
            data.status,
            data.amount
        );
    }

    /**
     * @notice Internal helper to get listing data
     */
    function _getListingData(bytes32 listingId) internal view returns (ListingData memory data) {
        address exchange = s_listingToExchange[listingId];

        if (exchange == address(erc721Exchange)) {
            data = _getListingFromERC721(listingId);
        } else if (exchange == address(erc1155Exchange)) {
            data = _getListingFromERC1155(listingId);
        } else {
            data = _getListingFallback(listingId);
        }
    }

    /**
     * @notice Internal helper to get listing from ERC721 exchange
     */
    function _getListingFromERC721(bytes32 listingId) internal view returns (ListingData memory data) {
        BaseNFTExchange.ListingStatus listingStatus;
        (
            data.contractAddress,
            data.tokenId,
            data.price,
            data.seller,
            data.duration,
            data.start,
            listingStatus,
            data.amount
        ) = erc721Exchange.s_listings(listingId);
        data.status = uint256(listingStatus);
    }

    /**
     * @notice Internal helper to get listing from ERC1155 exchange
     */
    function _getListingFromERC1155(bytes32 listingId) internal view returns (ListingData memory data) {
        BaseNFTExchange.ListingStatus listingStatus;
        (
            data.contractAddress,
            data.tokenId,
            data.price,
            data.seller,
            data.duration,
            data.start,
            listingStatus,
            data.amount
        ) = erc1155Exchange.s_listings(listingId);
        data.status = uint256(listingStatus);
    }

    /**
     * @notice Internal helper for fallback listing retrieval
     */
    function _getListingFallback(bytes32 listingId) internal view returns (ListingData memory data) {
        (data.contractAddress,,,,,,,) = erc721Exchange.s_listings(listingId);
        if (data.contractAddress != address(0)) {
            data = _getListingFromERC721(listingId);
        } else {
            data = _getListingFromERC1155(listingId);
        }
    }

    /**
     * @notice Get listings by seller (merged from both exchanges)
     */
    function getListingsBySeller(address seller) external view returns (bytes32[] memory) {
        bytes32[] memory erc721Listings = erc721Exchange.getListingsBySeller(seller);
        bytes32[] memory erc1155Listings = erc1155Exchange.getListingsBySeller(seller);

        return _mergeArrays(erc721Listings, erc1155Listings);
    }

    /**
     * @notice Get listings by collection (routes to appropriate exchange)
     */
    function getListingsByCollection(address contractAddress) external view returns (bytes32[] memory) {
        if (_isERC721(contractAddress)) {
            return erc721Exchange.getListingsByCollection(contractAddress);
        } else if (_isERC1155(contractAddress)) {
            return erc1155Exchange.getListingsByCollection(contractAddress);
        } else {
            revert NFTExchange__UnsupportedNFTType();
        }
    }

    // ============================================================================
    // REGISTRY FUNCTIONS
    // ============================================================================

    /**
     * @notice Get the addresses of the underlying exchanges
     */
    function getExchangeAddresses() external view returns (address erc721ExchangeAddr, address erc1155ExchangeAddr) {
        return (address(erc721Exchange), address(erc1155Exchange));
    }

    /**
     * @notice Get exchange address for specific NFT contract
     */
    function getExchangeForNFT(address nftContract) external view returns (address) {
        if (_isERC721(nftContract)) {
            return address(erc721Exchange);
        } else if (_isERC1155(nftContract)) {
            return address(erc1155Exchange);
        } else {
            revert NFTExchange__UnsupportedNFTType();
        }
    }

    /**
     * @notice Get total listings across both exchanges
     */
    function getTotalListings() external view returns (uint256) {
        return s_totalListings;
    }

    // ============================================================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================================================

    function _isERC721(address contractAddress) internal view returns (bool) {
        return IERC165(contractAddress).supportsInterface(type(IERC721).interfaceId);
    }

    function _isERC1155(address contractAddress) internal view returns (bool) {
        return IERC165(contractAddress).supportsInterface(type(IERC1155).interfaceId);
    }

    function _mergeArrays(bytes32[] memory array1, bytes32[] memory array2) internal pure returns (bytes32[] memory) {
        bytes32[] memory merged = new bytes32[](array1.length + array2.length);
        uint256 index = 0;

        for (uint256 i = 0; i < array1.length; i++) {
            merged[index] = array1[i];
            index++;
        }

        for (uint256 i = 0; i < array2.length; i++) {
            merged[index] = array2[i];
            index++;
        }

        return merged;
    }

    // ============================================================================
    // INTERFACE IMPLEMENTATIONS
    // ============================================================================

    function version() public pure override returns (string memory) {
        return "1.0.0";
    }

    function contractType() public pure override returns (string memory) {
        return "NFTExchangeRegistry";
    }

    function isActive() public pure override returns (bool) {
        return true;
    }

    // ============================================================================
    // IERC1155Receiver IMPLEMENTATION
    // ============================================================================

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IExchangeCore).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // ============================================================================
    // MISSING INTERFACE IMPLEMENTATIONS
    // ============================================================================

    function supportedStandard() external pure override returns (string memory) {
        return "ERC721/ERC1155";
    }

    function marketplaceWallet() external view override returns (address) {
        return erc721Exchange.marketplaceWallet();
    }

    function getTakerFee() external view override returns (uint256) {
        return erc721Exchange.s_takerFee();
    }

    function BPS_DENOMINATOR() external view override returns (uint256) {
        return erc721Exchange.BPS_DENOMINATOR();
    }
}
