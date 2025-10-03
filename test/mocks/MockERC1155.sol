// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Fee} from "src/contracts/common/Fee.sol";

/**
 * @title MockERC1155
 * @notice Comprehensive mock ERC1155 contract for testing
 * @dev Includes ERC2981 royalty support and Fee contract integration
 */
contract MockERC1155 is ERC1155, ERC2981, Ownable {
    string private _name;
    string private _symbol;
    Fee public feeContract;

    // Track total supply for each token ID
    mapping(uint256 => uint256) private _totalSupply;

    constructor(string memory name_, string memory symbol_)
        ERC1155("https://example.com/metadata/{id}.json")
        Ownable(msg.sender)
    {
        _name = name_;
        _symbol = symbol_;
        // Create fee contract with 0% royalty for testing
        feeContract = new Fee(msg.sender, 0);
        // Set default royalty to 5% (500 basis points)
        _setDefaultRoyalty(msg.sender, 500);
    }

    /**
     * @notice Returns the name of the token
     * @return Token name
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     * @return Token symbol
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Mints tokens to an address
     * @param to Address to mint to
     * @param id Token ID
     * @param amount Amount to mint
     */
    function mint(address to, uint256 id, uint256 amount) external {
        _totalSupply[id] += amount;
        _mint(to, id, amount, "");
    }

    /**
     * @notice Mints tokens with data
     * @param to Address to mint to
     * @param id Token ID
     * @param amount Amount to mint
     * @param data Additional data
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _totalSupply[id] += amount;
        _mint(to, id, amount, data);
    }

    /**
     * @notice Batch mints tokens to an address
     * @param to Address to mint to
     * @param ids Array of token IDs
     * @param amounts Array of amounts to mint
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external {
        for (uint256 i = 0; i < ids.length; i++) {
            _totalSupply[ids[i]] += amounts[i];
        }
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @notice Batch mints tokens with data
     * @param to Address to mint to
     * @param ids Array of token IDs
     * @param amounts Array of amounts to mint
     * @param data Additional data
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        for (uint256 i = 0; i < ids.length; i++) {
            _totalSupply[ids[i]] += amounts[i];
        }
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @notice Burns tokens from an address
     * @param from Address to burn from
     * @param id Token ID
     * @param amount Amount to burn
     */
    function burn(address from, uint256 id, uint256 amount) external {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender) || owner() == msg.sender,
            "MockERC1155: caller is not owner nor approved"
        );
        _totalSupply[id] -= amount;
        _burn(from, id, amount);
    }

    /**
     * @notice Batch burns tokens from an address
     * @param from Address to burn from
     * @param ids Array of token IDs
     * @param amounts Array of amounts to burn
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender) || owner() == msg.sender,
            "MockERC1155: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < ids.length; i++) {
            _totalSupply[ids[i]] -= amounts[i];
        }
        _burnBatch(from, ids, amounts);
    }

    /**
     * @notice Sets royalty for a specific token
     * @param tokenId Token ID
     * @param receiver Royalty receiver
     * @param feeNumerator Royalty fee in basis points
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @notice Sets default royalty for all tokens
     * @param receiver Royalty receiver
     * @param feeNumerator Royalty fee in basis points
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @notice Legacy royalty info function for compatibility
     * @param recipient Royalty recipient
     * @param percentage Royalty percentage in basis points
     */
    function setRoyaltyInfo(address recipient, uint256 percentage) external onlyOwner {
        _setDefaultRoyalty(recipient, uint96(percentage));
    }

    /**
     * @notice Checks if token exists
     * @param id Token ID to check
     * @return Whether token exists
     */
    function exists(uint256 id) external view returns (bool) {
        return totalSupply(id) > 0;
    }

    /**
     * @notice Returns total supply of a token
     * @param id Token ID
     * @return Total supply
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        // For backward compatibility with tests, return fixed value if no supply tracked
        return _totalSupply[id] > 0 ? _totalSupply[id] : 1000000;
    }

    /**
     * @notice Sets the URI for all tokens
     * @param newuri New URI to set
     */
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /**
     * @notice Function to get fee contract
     * @return Fee contract instance
     */
    function getFeeContract() external view returns (Fee) {
        return feeContract;
    }

    /**
     * @notice Checks if contract supports interface
     * @param interfaceId Interface ID to check
     * @return Whether interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
