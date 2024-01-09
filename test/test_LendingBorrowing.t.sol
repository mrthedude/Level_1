// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {basicLendingBorrowing} from "../src/LendingBorrowing.sol";
import {deployer} from "../script/script_LendingBorrowing.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract testingBorrowing is Test, basicLendingBorrowing {
    basicLendingBorrowing lendingContract;
    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    address public constant USER = address(1);

    function setUp() public {
        deployer deployContract = new deployer();
        lendingContract = deployContract.run();
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    ////////// Testing deposit //////////

    function test_RevertWhen_depositIs_0() public {
        vm.prank(USER);
        vm.expectRevert(basicLendingBorrowing.noFundsDeposited.selector);
        lendingContract.deposit{value: 0}();
    }

    function testIfContractBalanceIncreasesAfterDepositByAmountSent() public {
        vm.prank(USER);
        lendingContract.deposit{value: 1 ether}();
        assertEq(address(lendingContract).balance, 1 ether);
    }

    function testIfUserDepositsAreTrackedInMapping() public {
        vm.prank(USER);
        lendingContract.deposit{value: 1.5 ether}();
        assertEq(lendingContract.getDepositBalance(USER), 1.5 ether);
    }

    ////////// Testing withdraw //////////

    function test_RevertWhen_withdrawIsGreaterThanDeposit() public {
        vm.prank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.cantWithdrawMoreThanDeposited.selector);
        lendingContract.withdraw(2e18);
    }

    function test_RevertWhen_withdrawCalledWithFundsBorrowed() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        lendingContract.borrow(1e17);
        vm.expectRevert(basicLendingBorrowing.cannotWithdrawWhileFundsAreBorrowed.selector);
        lendingContract.withdraw(1e17);
        vm.stopPrank();
    }

    function testUserBalanceIncreaseByWithdrawAmount() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 2 ether}();
        lendingContract.withdraw(1e18);
        vm.stopPrank();
        assertEq(address(USER).balance, 9e18);
    }

    ////////// Testing borrow //////////

    function test_RevertWhen_noFundsDeposited_borrow() public {
        vm.prank(USER);
        vm.expectRevert(basicLendingBorrowing.noFundsDeposited.selector);
        lendingContract.borrow(1);
    }

    function test_RevertWhen_borrowingExceedsMaximumLTV() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.borrowingAmountExceedsCollateralLTVRequirements.selector);
        lendingContract.borrow(1.51e18);
        vm.stopPrank();
    }

    function test_RevertWhen_notEnoughMoneyInContractForBorrowing() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.notEnoughEthInContractToLend.selector);
        lendingContract.borrow(1.1e18);
        vm.stopPrank();
    }

    function testUserBorrowBalanceIncreases() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 2 ether}();
        lendingContract.borrow(1e18);
        assertEq(lendingContract.getBorrowedBalance(USER), 1 ether);
        vm.stopPrank();
    }

    function testIfUserBalanceIncreasesAfterBorrow() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 2 ether}();
        lendingContract.borrow(1e18);
        assertEq(address(USER).balance, 9 ether);
    }

    ////////// Testing repay //////////

    function test_RevertWhen_repayAmountDifferentThanBorrow() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 4e18}();
        lendingContract.borrow(2e18);
        vm.expectRevert(basicLendingBorrowing.exactBorrowedBalanceMustBeRepaid.selector);
        lendingContract.repay(1e18);
        vm.stopPrank();
    }

    function testRepaymentAmountIsAddedToContract() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 4e18}();
        console.log("Initial Contract Balance: ", address(lendingContract).balance / 1e18);
        lendingContract.borrow(2e18);
        console.log("Contract balance AFTER BORROWING: ", address(lendingContract).balance / 1e18);
        lendingContract.repay(2e18);
        console.log("Contract balance AFTER REPAYMENT: ", address(lendingContract).balance / 1e18);
        assertEq(lendingContract.getContractBalance(), 4e18);
        vm.stopPrank();
    }

    function testBorrowedBalanceSetToZeroAfterRepayment() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1e18}();
        lendingContract.borrow(5e17);
        lendingContract.repay(5e17);
        assertEq(lendingContract.getBorrowedBalance(USER), 0);
    }

    ////////// Testing rug //////////

    function test_RevertWhen_MsgSenderIsNotOwner() public {
        vm.prank(USER);
        lendingContract.deposit{value: 1e18}();
        vm.expectRevert(basicLendingBorrowing.onlyTheOwnerCanRug.selector);
        lendingContract.rug();
    }

    function test_RevertWhen_noMoneyInContractToRug() public {
        address ownerAddress = lendingContract.getOwnerAddress();
        vm.prank(ownerAddress);
        vm.expectRevert(basicLendingBorrowing.withdrawError.selector);
        lendingContract.rug();
    }
}
