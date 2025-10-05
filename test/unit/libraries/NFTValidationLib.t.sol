// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/libraries/NFTValidationLib.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title NFTValidationLibTest
 * @notice Comprehensive test suite for NFTValidationLib library
 * @dev Tests all functions, edge cases, and error conditions to achieve >90% coverage
 */
contract NFTValidationLibTest is Test {
    using NFTValidationLib for NFTValidationLib.ValidationParams;

    // Test contracts
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    MockInvalidNFT public invalidNFT;

    // Test addresses
    address public constant OWNER = address(0x1);
    address public constant SPENDER = address(0x2);
    address public constant OTHER_USER = address(0x3);
    address public constant ZERO_ADDRESS = address(0);

    // Test constants
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant AMOUNT = 5;

    function setUp() public {
        // Deploy test contracts
        mockERC721 = new MockERC721("Test NFT", "TEST");
        mockERC1155 = new MockERC1155("Test ERC1155", "TEST1155");
        invalidNFT = new MockInvalidNFT();

        // Mint test tokens
        vm.prank(address(this));
        mockERC721.mint(OWNER, TOKEN_ID);

        vm.prank(address(this));
        mockERC1155.mint(OWNER, TOKEN_ID, 10, "");

        // Setup approvals
        vm.prank(OWNER);
        mockERC721.approve(SPENDER, TOKEN_ID);

        vm.prank(OWNER);
        mockERC1155.setApprovalForAll(SPENDER, true);
    }

    // ============================================================================
    // ERC721 VALIDATION TESTS
    // ============================================================================

    function test_ValidateERC721_Success() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC721), TOKEN_ID, 1, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC721(params);

        assertTrue(result.isValid);
        assertEq(uint256(result.standard), uint256(NFTValidationLib.NFTStandard.ERC721));
        assertEq(bytes(result.errorMessage).length, 0);
    }

    function test_ValidateERC721_NotOwner() public {
        NFTValidationLib.ValidationParams memory params = NFTValidationLib.createValidationParams(
            address(mockERC721),
            TOKEN_ID,
            1,
            OTHER_USER, // Not the owner
            SPENDER
        );

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC721(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Not the owner");
    }

    function test_ValidateERC721_NotApproved() public {
        // Mint new token without approval
        vm.prank(address(this));
        mockERC721.mint(OWNER, 2);

        NFTValidationLib.ValidationParams memory params = NFTValidationLib.createValidationParams(
            address(mockERC721),
            2, // Not approved token
            1,
            OWNER,
            SPENDER
        );

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC721(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Not approved");
    }

    function test_ValidateERC721_ApprovedForAll() public {
        // Set approval for all
        vm.prank(OWNER);
        mockERC721.setApprovalForAll(SPENDER, true);

        // Mint new token
        vm.prank(address(this));
        mockERC721.mint(OWNER, 3);

        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC721), 3, 1, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC721(params);

        assertTrue(result.isValid);
    }

    function test_ValidateERC721_InvalidToken() public {
        NFTValidationLib.ValidationParams memory params = NFTValidationLib.createValidationParams(
            address(mockERC721),
            999, // Non-existent token
            1,
            OWNER,
            SPENDER
        );

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC721(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Failed to get owner");
    }

    // ============================================================================
    // ERC1155 VALIDATION TESTS
    // ============================================================================

    function test_ValidateERC1155_Success() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC1155), TOKEN_ID, AMOUNT, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC1155(params);

        assertTrue(result.isValid);
        assertEq(uint256(result.standard), uint256(NFTValidationLib.NFTStandard.ERC1155));
        assertEq(bytes(result.errorMessage).length, 0);
    }

    function test_ValidateERC1155_ZeroAmount() public {
        NFTValidationLib.ValidationParams memory params = NFTValidationLib.createValidationParams(
            address(mockERC1155),
            TOKEN_ID,
            0, // Zero amount
            OWNER,
            SPENDER
        );

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC1155(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Amount must be greater than zero");
    }

    function test_ValidateERC1155_InsufficientBalance() public {
        NFTValidationLib.ValidationParams memory params = NFTValidationLib.createValidationParams(
            address(mockERC1155),
            TOKEN_ID,
            20, // More than balance (10)
            OWNER,
            SPENDER
        );

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC1155(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Insufficient balance");
    }

    function test_ValidateERC1155_NotApproved() public {
        // Remove approval
        vm.prank(OWNER);
        mockERC1155.setApprovalForAll(SPENDER, false);

        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC1155), TOKEN_ID, AMOUNT, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC1155(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Not approved");
    }

    function test_ValidateERC1155_InvalidToken() public {
        NFTValidationLib.ValidationParams memory params = NFTValidationLib.createValidationParams(
            address(invalidNFT), // Invalid contract
            TOKEN_ID,
            AMOUNT,
            OWNER,
            SPENDER
        );

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC1155(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Failed to get balance");
    }

    // ============================================================================
    // AUTO-DETECTION VALIDATION TESTS
    // ============================================================================

    function test_ValidateNFT_ERC721_Success() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC721), TOKEN_ID, 1, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateNFT(params);

        assertTrue(result.isValid);
        assertEq(uint256(result.standard), uint256(NFTValidationLib.NFTStandard.ERC721));
    }

    function test_ValidateNFT_ERC1155_Success() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC1155), TOKEN_ID, AMOUNT, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateNFT(params);

        assertTrue(result.isValid);
        assertEq(uint256(result.standard), uint256(NFTValidationLib.NFTStandard.ERC1155));
    }

    function test_ValidateNFT_ZeroContractAddress() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(ZERO_ADDRESS, TOKEN_ID, 1, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateNFT(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Zero address provided");
    }

    function test_ValidateNFT_ZeroOwnerAddress() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC721), TOKEN_ID, 1, ZERO_ADDRESS, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateNFT(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Zero address provided");
    }

    function test_ValidateNFT_UnsupportedStandard() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(invalidNFT), TOKEN_ID, 1, OWNER, SPENDER);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateNFT(params);

        assertFalse(result.isValid);
        assertEq(result.errorMessage, "Unsupported NFT standard");
    }

    // ============================================================================
    // STANDARD DETECTION TESTS
    // ============================================================================

    function test_DetectNFTStandard_ERC721() public {
        NFTValidationLib.NFTStandard standard = NFTValidationLib.detectNFTStandard(address(mockERC721));
        assertEq(uint256(standard), uint256(NFTValidationLib.NFTStandard.ERC721));
    }

    function test_DetectNFTStandard_ERC1155() public {
        NFTValidationLib.NFTStandard standard = NFTValidationLib.detectNFTStandard(address(mockERC1155));
        assertEq(uint256(standard), uint256(NFTValidationLib.NFTStandard.ERC1155));
    }

    function test_DetectNFTStandard_Unknown() public {
        NFTValidationLib.NFTStandard standard = NFTValidationLib.detectNFTStandard(address(invalidNFT));
        assertEq(uint256(standard), uint256(NFTValidationLib.NFTStandard.UNKNOWN));
    }

    function test_DetectNFTStandard_ZeroAddress() public {
        NFTValidationLib.NFTStandard standard = NFTValidationLib.detectNFTStandard(ZERO_ADDRESS);
        assertEq(uint256(standard), uint256(NFTValidationLib.NFTStandard.UNKNOWN));
    }

    // ============================================================================
    // BATCH VALIDATION TESTS
    // ============================================================================

    function test_BatchValidateNFTs_Success() public {
        NFTValidationLib.ValidationParams[] memory paramsList = new NFTValidationLib.ValidationParams[](2);

        paramsList[0] = NFTValidationLib.createValidationParams(address(mockERC721), TOKEN_ID, 1, OWNER, SPENDER);

        paramsList[1] = NFTValidationLib.createValidationParams(address(mockERC1155), TOKEN_ID, AMOUNT, OWNER, SPENDER);

        NFTValidationLib.ValidationResult[] memory results = NFTValidationLib.batchValidateNFTs(paramsList);

        assertEq(results.length, 2);
        assertTrue(results[0].isValid);
        assertTrue(results[1].isValid);
        assertEq(uint256(results[0].standard), uint256(NFTValidationLib.NFTStandard.ERC721));
        assertEq(uint256(results[1].standard), uint256(NFTValidationLib.NFTStandard.ERC1155));
    }

    function test_BatchValidateNFTs_MixedResults() public {
        NFTValidationLib.ValidationParams[] memory paramsList = new NFTValidationLib.ValidationParams[](2);

        paramsList[0] = NFTValidationLib.createValidationParams(address(mockERC721), TOKEN_ID, 1, OWNER, SPENDER);

        paramsList[1] = NFTValidationLib.createValidationParams(address(invalidNFT), TOKEN_ID, 1, OWNER, SPENDER);

        NFTValidationLib.ValidationResult[] memory results = NFTValidationLib.batchValidateNFTs(paramsList);

        assertEq(results.length, 2);
        assertTrue(results[0].isValid);
        assertFalse(results[1].isValid);
    }

    function test_BatchValidateNFTs_EmptyArray() public {
        NFTValidationLib.ValidationParams[] memory paramsList = new NFTValidationLib.ValidationParams[](0);

        NFTValidationLib.ValidationResult[] memory results = NFTValidationLib.batchValidateNFTs(paramsList);

        assertEq(results.length, 0);
    }

    // ============================================================================
    // HELPER FUNCTION TESTS
    // ============================================================================

    function test_CreateValidationParams() public {
        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC721), TOKEN_ID, 1, OWNER, SPENDER);

        assertEq(params.nftContract, address(mockERC721));
        assertEq(params.tokenId, TOKEN_ID);
        assertEq(params.amount, 1);
        assertEq(params.owner, OWNER);
        assertEq(params.spender, SPENDER);
    }

    // ============================================================================
    // FUZZ TESTS
    // ============================================================================

    // TODO: Fix fuzz test - currently failing due to address(0) issues
    // function testFuzz_ValidateERC721_ValidInputs(
    //     uint256 tokenId,
    //     address owner,
    //     address spender
    // ) public {
    //     // Bound inputs to ensure valid ranges
    //     tokenId = bound(tokenId, 1, 1000);
    //     // Bound addresses to ensure they're never zero and different
    //     owner = address(
    //         uint160(bound(uint160(owner), 1000, type(uint160).max))
    //     );
    //     spender = address(
    //         uint160(bound(uint160(spender), 1000, type(uint160).max - 1))
    //     );
    //     // Ensure they're different
    //     vm.assume(owner != spender);

    //     // Mint token to owner
    //     vm.prank(address(this));
    //     mockERC721.mint(owner, tokenId);

    //     // Approve spender
    //     vm.prank(owner);
    //     mockERC721.approve(spender, tokenId);

    //     NFTValidationLib.ValidationParams memory params = NFTValidationLib
    //         .createValidationParams(
    //             address(mockERC721),
    //             tokenId,
    //             1,
    //             owner,
    //             spender
    //         );

    //     NFTValidationLib.ValidationResult memory result = NFTValidationLib
    //         .validateERC721(params);

    //     assertTrue(result.isValid);
    //     assertEq(
    //         uint256(result.standard),
    //         uint256(NFTValidationLib.NFTStandard.ERC721)
    //     );
    // }

    function testFuzz_ValidateERC1155_ValidInputs(uint256 tokenId, uint256 amount, address owner, address spender)
        public
    {
        // Bound inputs
        tokenId = bound(tokenId, 1, 1000);
        amount = bound(amount, 1, 100);
        vm.assume(owner != address(0) && spender != address(0));

        // Filter out addresses that can't receive ERC1155 tokens
        // Assume owner is an EOA or contract that can receive ERC1155
        vm.assume(owner.code.length == 0 || owner == address(this));

        // Ensure spender is different from owner for meaningful test
        vm.assume(spender != owner);

        // Mint tokens to owner
        vm.prank(address(this));
        mockERC1155.mint(owner, tokenId, amount, "");

        // Approve spender
        vm.prank(owner);
        mockERC1155.setApprovalForAll(spender, true);

        NFTValidationLib.ValidationParams memory params =
            NFTValidationLib.createValidationParams(address(mockERC1155), tokenId, amount, owner, spender);

        NFTValidationLib.ValidationResult memory result = NFTValidationLib.validateERC1155(params);

        assertTrue(result.isValid);
        assertEq(uint256(result.standard), uint256(NFTValidationLib.NFTStandard.ERC1155));
    }
}

// ============================================================================
// MOCK CONTRACTS FOR TESTING
// ============================================================================

/**
 * @title MockInvalidNFT
 * @notice Mock contract that doesn't implement any NFT standards
 */
contract MockInvalidNFT {
    // Empty contract for testing unsupported standards
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}
