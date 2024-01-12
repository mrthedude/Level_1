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
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.cantWithdrawMoreThanDeposited.selector);
        lendingContract.withdraw(1.1 ether);
        vm.stopPrank();
        console.log("Contract balance: ", address(lendingContract).balance);
    }

    function test_RevertWhen_withdrawCalledWithFundsBorrowed() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        lendingContract.borrow(0.1 ether);
        vm.expectRevert(basicLendingBorrowing.cannotWithdrawWhileFundsAreBorrowed.selector);
        lendingContract.withdraw(0.1 ether);
        vm.stopPrank();
    }

    function testUserBalanceIncreaseByWithdrawAmount() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 2 ether}();
        lendingContract.withdraw(1 ether);
        vm.stopPrank();
        assertEq(USER.balance, 9 ether);
    }

    ////////// Testing borrow //////////

    function test_RevertWhen_noFundsDeposited_borrow() public {
        vm.prank(USER);
        vm.expectRevert(basicLendingBorrowing.noFundsDeposited.selector);
        lendingContract.borrow(1 ether);
    }

    function test_RevertWhen_borrowingExceedsMaximumLTV() public {
        lendingContract.deposit{value: 1 ether}();
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.borrowingAmountExceedsCollateralLTVRequirements.selector);
        lendingContract.borrow(1.51 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_notEnoughMoneyInContractForBorrowing() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.notEnoughEthInContractToLend.selector);
        lendingContract.borrow(1.1 ether);
        vm.stopPrank();
        console.log("Contract Balance: ", address(lendingContract).balance);
    }

    function testUserBorrowBalanceIncreases() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 2 ether}();
        lendingContract.borrow(1 ether);
        assertEq(lendingContract.getBorrowedBalance(USER), 1 ether);
        vm.stopPrank();
    }

    function testIfUserBalanceIncreasesAfterBorrow() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 2 ether}();
        lendingContract.borrow(1 ether);
        assertEq(address(USER).balance, 9 ether);
    }

    ////////// Testing repay //////////

    function test_RevertWhen_repayAmountDifferentThanBorrow() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 4 ether}();
        lendingContract.borrow(2 ether);
        vm.expectRevert(basicLendingBorrowing.exactBorrowedBalanceMustBeRepaid.selector);
        lendingContract.repay{value: 1 ether}();
        vm.stopPrank();
        console.log("Contract Balance: ", address(lendingContract).balance);
    }

    function testRepaymentAmountIsAddedToContract() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 4 ether}();
        lendingContract.borrow(2 ether);
        lendingContract.repay{value: 2 ether}();
        vm.stopPrank();
        assertEq(address(lendingContract).balance, 4 ether);
    }

    function testBorrowedBalanceSetToZeroAfterRepayment() public {
        vm.startPrank(USER);
        lendingContract.deposit{value: 1 ether}();
        lendingContract.borrow(0.5 ether);
        lendingContract.repay{value: 0.5 ether}();
        vm.stopPrank();
        assertEq(lendingContract.getBorrowedBalance(USER), 0);
    }

    ////////// Testing rug //////////

    function test_RevertWhen_MsgSenderIsNotOwner() public {
        vm.prank(USER);
        lendingContract.deposit{value: 1 ether}();
        vm.expectRevert(basicLendingBorrowing.onlyTheOwnerCanRug.selector);
        lendingContract.rug();
    }

    function test_RevertWhen_noMoneyInContractToRug() public {
        vm.prank(i_owner);
        vm.expectRevert(basicLendingBorrowing.withdrawError.selector);
        lendingContract.rug();
    }

    function testRugFundsTransferToOWner() public {
        vm.startPrank(i_owner);
        lendingContract.deposit{value: 2 ether}();
        uint256 originalBalance = i_owner.balance;
        uint256 contractValue = address(lendingContract).balance;
        lendingContract.rug();
        assertEq(i_owner.balance, originalBalance + contractValue);
        vm.stopPrank();
    }
}
