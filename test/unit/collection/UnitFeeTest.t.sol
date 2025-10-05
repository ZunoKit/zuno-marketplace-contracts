// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Fee} from "src/common/Fee.sol";
import {MAX_ROYALTY_FEE} from "src/types/ListingTypes.sol";
import "src/errors/FeeErrors.sol";

contract UnitFeeTest is Test {
    struct TestSetup {
        Fee fee;
        address owner;
        address user;
    }

    TestSetup private setup;
    Fee private fee;
    address private owner;
    address private user;
    uint256 private constant INITIAL_ROYALTY_FEE = 500; // 5%

    function setUp() public {
        setup.owner = makeAddr("owner");
        setup.user = makeAddr("user");
        vm.startPrank(setup.owner);
        setup.fee = new Fee(setup.owner, INITIAL_ROYALTY_FEE);
        vm.stopPrank();
    }

    function test_Constructor_ValidFee() public {
        assertEq(setup.fee.s_royaltyFee(), INITIAL_ROYALTY_FEE);
        assertEq(setup.fee.owner(), setup.owner);
    }

    function test_Constructor_InvalidFee() public {
        vm.expectRevert(Fee__InvalidRoyaltyFee.selector);
        new Fee(setup.owner, MAX_ROYALTY_FEE + 1);
    }

    function test_SetRoyaltyFee_Valid() public {
        uint256 newFee = 750; // 7.5%
        vm.startPrank(setup.owner);
        setup.fee.setRoyaltyFee(newFee);
        assertEq(setup.fee.s_royaltyFee(), newFee);
        vm.stopPrank();
    }

    function test_SetRoyaltyFee_Invalid() public {
        vm.startPrank(setup.owner);
        vm.expectRevert(Fee__InvalidRoyaltyFee.selector);
        setup.fee.setRoyaltyFee(MAX_ROYALTY_FEE + 1);
        vm.stopPrank();
    }

    function test_SetRoyaltyFee_NotOwner() public {
        vm.startPrank(setup.user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", setup.user));
        setup.fee.setRoyaltyFee(750);
        vm.stopPrank();
    }

    function test_GetRoyaltyFee() public {
        assertEq(setup.fee.getRoyaltyFee(), INITIAL_ROYALTY_FEE);
    }

    function test_RoyaltyInfo_ZeroPrice() public {
        (address receiver, uint256 amount) = setup.fee.royaltyInfo(1, 0);
        assertEq(receiver, setup.owner);
        assertEq(amount, 0);
    }

    function test_RoyaltyInfo_NormalPrice() public {
        uint256 salePrice = 1 ether;
        (address receiver, uint256 amount) = setup.fee.royaltyInfo(1, salePrice);
        assertEq(receiver, setup.owner);
        assertEq(amount, (salePrice * INITIAL_ROYALTY_FEE) / 10000);
    }

    function test_RoyaltyInfo_MaxPrice() public {
        uint256 salePrice = 1000 ether; // Use a large but reasonable price
        (address receiver, uint256 amount) = setup.fee.royaltyInfo(1, salePrice);
        assertEq(receiver, setup.owner);
        assertEq(amount, (salePrice * INITIAL_ROYALTY_FEE) / 10000);
    }

    // ============================================================================
    // ADDITIONAL TESTS FOR BETTER COVERAGE
    // ============================================================================

    function test_Constructor_ZeroFee() public {
        vm.startPrank(setup.owner);
        Fee zeroFee = new Fee(setup.owner, 0);
        assertEq(zeroFee.s_royaltyFee(), 0);
        vm.stopPrank();
    }

    function test_Constructor_MaxValidFee() public {
        vm.startPrank(setup.owner);
        Fee maxFee = new Fee(setup.owner, MAX_ROYALTY_FEE);
        assertEq(maxFee.s_royaltyFee(), MAX_ROYALTY_FEE);
        vm.stopPrank();
    }

    function test_SetRoyaltyFee_ZeroFee() public {
        vm.startPrank(setup.owner);
        setup.fee.setRoyaltyFee(0);
        assertEq(setup.fee.s_royaltyFee(), 0);
        vm.stopPrank();
    }

    function test_SetRoyaltyFee_MaxValidFee() public {
        vm.startPrank(setup.owner);
        setup.fee.setRoyaltyFee(MAX_ROYALTY_FEE);
        assertEq(setup.fee.s_royaltyFee(), MAX_ROYALTY_FEE);
        vm.stopPrank();
    }

    function test_RoyaltyInfo_DifferentTokenIds() public {
        uint256 salePrice = 1 ether;

        // Test with different token IDs - should all return same result
        (address receiver1, uint256 amount1) = setup.fee.royaltyInfo(1, salePrice);
        (address receiver2, uint256 amount2) = setup.fee.royaltyInfo(999, salePrice);
        (address receiver3, uint256 amount3) = setup.fee.royaltyInfo(0, salePrice);

        assertEq(receiver1, receiver2);
        assertEq(receiver2, receiver3);
        assertEq(amount1, amount2);
        assertEq(amount2, amount3);
    }

    function test_RoyaltyInfo_SmallAmounts() public {
        // Test with 1 wei
        (address receiver, uint256 amount) = setup.fee.royaltyInfo(1, 1);
        assertEq(receiver, setup.owner);
        assertEq(amount, 0); // Should round down to 0

        // Test with small amount that results in non-zero royalty
        uint256 salePrice = 10000; // With 5% fee, this gives 50 wei
        (receiver, amount) = setup.fee.royaltyInfo(1, salePrice);
        assertEq(receiver, setup.owner);
        assertEq(amount, (salePrice * INITIAL_ROYALTY_FEE) / 10000);
    }

    function test_RoyaltyInfo_AfterFeeChange() public {
        uint256 salePrice = 1 ether;
        uint256 newFee = 1000; // 10%

        // Get initial royalty
        (address receiver1, uint256 amount1) = setup.fee.royaltyInfo(1, salePrice);

        // Change fee
        vm.startPrank(setup.owner);
        setup.fee.setRoyaltyFee(newFee);
        vm.stopPrank();

        // Get new royalty
        (address receiver2, uint256 amount2) = setup.fee.royaltyInfo(1, salePrice);

        assertEq(receiver1, receiver2); // Receiver should be same
        assertTrue(amount2 > amount1); // New amount should be higher
        assertEq(amount2, (salePrice * newFee) / 10000);
    }

    function test_SupportsInterface() public {
        // Test ERC2981 interface support
        assertTrue(setup.fee.supportsInterface(0x2a55205a)); // ERC2981 interface ID

        // Test ERC165 interface support
        assertTrue(setup.fee.supportsInterface(0x01ffc9a7)); // ERC165 interface ID

        // Test unsupported interface
        assertFalse(setup.fee.supportsInterface(0x12345678));
    }

    function test_RoyaltyCalculation_Precision() public {
        // Test precision with various fee percentages
        uint256 salePrice = 12345 wei;

        vm.startPrank(setup.owner);

        // Test 0.01% (1 basis point)
        setup.fee.setRoyaltyFee(1);
        (, uint256 amount) = setup.fee.royaltyInfo(1, salePrice);
        assertEq(amount, (salePrice * 1) / 10000);

        // Test 2.5% (250 basis points)
        setup.fee.setRoyaltyFee(250);
        (, amount) = setup.fee.royaltyInfo(1, salePrice);
        assertEq(amount, (salePrice * 250) / 10000);

        // Test 10% (1000 basis points)
        setup.fee.setRoyaltyFee(1000);
        (, amount) = setup.fee.royaltyInfo(1, salePrice);
        assertEq(amount, (salePrice * 1000) / 10000);

        vm.stopPrank();
    }

    function test_EdgeCase_MaxUint256Price() public {
        // Test with maximum possible price (edge case)
        uint256 maxPrice = type(uint256).max;

        vm.startPrank(setup.owner);
        setup.fee.setRoyaltyFee(1); // Use 0.01% to avoid overflow
        vm.stopPrank();

        (address receiver, uint256 amount) = setup.fee.royaltyInfo(1, maxPrice);
        assertEq(receiver, setup.owner);
        // Should not overflow
        assertTrue(amount <= maxPrice);
    }
}
