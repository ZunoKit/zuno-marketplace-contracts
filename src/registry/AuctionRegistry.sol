// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAuctionRegistry} from "../interfaces/registry/IAuctionRegistry.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AuctionRegistry
 * @notice Central registry for managing auction contracts and factory
 * @dev Provides unified access to different auction types
 */
contract AuctionRegistry is IAuctionRegistry, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping from auction type to auction contract address
    mapping(AuctionType => address) private s_auctionContracts;

    // Auction factory address
    address private s_auctionFactory;

    // Mapping to check if address is a registered auction contract
    mapping(address => bool) private s_isAuctionContract;

    // Array to track all registered auction types
    AuctionType[] private s_registeredTypes;

    error AuctionRegistry__ZeroAddress();
    error AuctionRegistry__AuctionAlreadyRegistered();
    error AuctionRegistry__AuctionNotRegistered();
    error AuctionRegistry__FactoryNotSet();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @inheritdoc IAuctionRegistry
     */
    function getAuctionContract(AuctionType auctionType) external view override returns (address) {
        address auctionContract = s_auctionContracts[auctionType];
        if (auctionContract == address(0)) revert AuctionRegistry__AuctionNotRegistered();
        return auctionContract;
    }

    /**
     * @inheritdoc IAuctionRegistry
     */
    function getAuctionFactory() external view override returns (address) {
        if (s_auctionFactory == address(0)) revert AuctionRegistry__FactoryNotSet();
        return s_auctionFactory;
    }

    /**
     * @inheritdoc IAuctionRegistry
     */
    function registerAuction(AuctionType auctionType, address auctionContract) external override onlyRole(ADMIN_ROLE) {
        if (auctionContract == address(0)) revert AuctionRegistry__ZeroAddress();
        if (s_auctionContracts[auctionType] != address(0)) revert AuctionRegistry__AuctionAlreadyRegistered();

        s_auctionContracts[auctionType] = auctionContract;
        s_isAuctionContract[auctionContract] = true;
        s_registeredTypes.push(auctionType);

        emit AuctionRegistered(auctionType, auctionContract);
    }

    /**
     * @inheritdoc IAuctionRegistry
     */
    function updateAuctionFactory(address newFactory) external override onlyRole(ADMIN_ROLE) {
        if (newFactory == address(0)) revert AuctionRegistry__ZeroAddress();

        address oldFactory = s_auctionFactory;
        s_auctionFactory = newFactory;

        emit AuctionFactoryUpdated(oldFactory, newFactory);
    }

    /**
     * @inheritdoc IAuctionRegistry
     */
    function isRegisteredAuction(address auctionContract) external view override returns (bool) {
        return s_isAuctionContract[auctionContract];
    }

    /**
     * @inheritdoc IAuctionRegistry
     */
    function getAllAuctions() external view override returns (AuctionType[] memory types, address[] memory contracts) {
        uint256 length = s_registeredTypes.length;
        types = new AuctionType[](length);
        contracts = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            types[i] = s_registeredTypes[i];
            contracts[i] = s_auctionContracts[s_registeredTypes[i]];
        }

        return (types, contracts);
    }
}
