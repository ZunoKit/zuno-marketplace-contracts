// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Fee} from "src/common/Fee.sol";

/**
 * @title MockERC721
 * @notice Comprehensive mock ERC721 contract for testing
 * @dev Includes ERC2981 royalty support and Fee contract integration
 */
contract MockERC721 is ERC721, ERC2981, Ownable {
    uint256 private _tokenIdCounter;
    Fee public feeContract;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {
        // Create fee contract with 0% royalty for testing
        feeContract = new Fee(msg.sender, 0);
        // Set default royalty to 5% (500 basis points)
        _setDefaultRoyalty(msg.sender, 500);
    }

    /**
     * @notice Mints a new token
     * @param to Address to mint to
     * @param tokenId Token ID to mint
     */
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    /**
     * @notice Safe mint with auto-incrementing token ID
     * @param to Address to mint to
     * @return tokenId The minted token ID
     */
    function safeMint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice Batch mint tokens
     * @param to Address to mint to
     * @param quantity Number of tokens to mint
     */
    function batchMint(address to, uint256 quantity) external {
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter++;
            _mint(to, _tokenIdCounter);
        }
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
     * @notice Returns the current token ID counter
     * @return Current token ID counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @notice Burns a token (for testing purposes)
     * @param tokenId Token ID to burn
     */
    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender);
        _burn(tokenId);
    }

    /**
     * @notice Checks if token exists
     * @param tokenId Token ID to check
     * @return Whether token exists
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @notice Sets the fee contract (for testing purposes)
     * @param _feeContract Address of the fee contract
     */
    function setFeeContract(address _feeContract) external onlyOwner {
        feeContract = Fee(_feeContract);
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
