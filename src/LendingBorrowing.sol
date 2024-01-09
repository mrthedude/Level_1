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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract basicLendingBorrowing {
    error noFundsDeposited();
    error borrowingAmountExceedsCollateralLTVRequirements();
    error cannotWithdrawWhileFundsAreBorrowed();
    error notEnoughEthInContractToLend();
    error exactBorrowedBalanceMustBeRepaid();
    error withdrawError();
    error repaymentFailed();
    error calledContractWithNonApplicableData();
    error borrowingFailed();
    error onlyTheOwnerCanRug();
    error cantWithdrawMoreThanDeposited();

    address public immutable i_owner;
    uint256 constant MAXIMUMCOLLATERALRATIO = 1.5e18; // LTV Ratio of 150%
    mapping(address user => uint256 amount) internal depositBalance;
    mapping(address user => uint256 amount) internal borrowedBalance;

    event UserDepositedFunds(address indexed user, uint256 indexed depositAmount);
    event UserWithdrewDeposit(address indexed user, uint256 withdrawAmount, uint256 indexed remainingDepositBalance);
    event UserBorrowedFunds(address indexed user, uint256 indexed borrowAmount, uint256 indexed totalBorrowAmount);
    event UserRepaidBorrowedAmount(address indexed ser, uint256 repaymentAmount, uint256 indexed totalContractBalance);
    event safu();

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert onlyTheOwnerCanRug();
        }
        _;
    }

    constructor() {
        i_owner = msg.sender;
    }

    receive() external payable {}

    fallback() external {
        revert calledContractWithNonApplicableData();
    }

    function deposit() external payable {
        /**
         * Functionalities:
         * 1. Receives user ETH deposits
         * 2. Reverts if no msg.value is sent
         * 3. Tracks user deposits in a mapping to track balances for borrowing parameters
         * 4. Emits event for user deposits
         * DONE
         */
        uint256 amount = msg.value;
        if (amount == 0) {
            revert noFundsDeposited();
        }
        depositBalance[msg.sender] += amount;
        emit UserDepositedFunds(msg.sender, depositBalance[msg.sender]);
    }

    function withdraw(uint256 amount) external {
        /**
         * Functionalities:
         * 1. checks to see if the withdraw amount > depositBalance
         * 2. checks to see if user has an open lending position
         * 3. Sends the amount to the user's address
         * 4. subtracts the user's depositBalance by the amount
         * 5. Emits an event for a user withdrawing their deposit
         * DONE
         */
        if (amount > depositBalance[msg.sender]) {
            revert cantWithdrawMoreThanDeposited();
        }

        if (borrowedBalance[msg.sender] != 0) {
            revert cannotWithdrawWhileFundsAreBorrowed();
        }

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert withdrawError();
        }
        depositBalance[msg.sender] -= amount;
        emit UserWithdrewDeposit(msg.sender, amount, depositBalance[msg.sender]);
    }

    function borrow(uint256 amount) external {
        /**
         * Functionalities:
         * 1. Checks to see if user has deposited funds
         * 2. Checks to see if borrowing the amount specified will cause the user's LTV ratio to exceed the MAXIMUMCOLLATERALRATIO
         * 3. Checks to see if the contract has that amount of ETH to lend
         * 4. Increases the user's borrowedBalance
         * 5. Sends ETH amount to user's address
         * 6. Emits borrow event
         * DONE
         */
        if (depositBalance[msg.sender] == 0) {
            revert noFundsDeposited();
        }

        if (((amount + borrowedBalance[msg.sender]) * 1e18) / depositBalance[msg.sender] > MAXIMUMCOLLATERALRATIO) {
            revert borrowingAmountExceedsCollateralLTVRequirements();
        }

        if (address(this).balance < amount) {
            revert notEnoughEthInContractToLend();
        }
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert borrowingFailed();
        }
        borrowedBalance[msg.sender] += amount;
        emit UserBorrowedFunds(msg.sender, amount, borrowedBalance[msg.sender]);
    }

    function repay(uint256 amount) external payable {
        /**
         * Functionalities:
         * 1. checks if repayment amount == borrowedBalance
         * 3. deposits specified amount into contract
         * 2. Sets borrowedBalance[msg.sender] = 0
         * 4. Emits event for repayment
         *
         */
        if (amount != borrowedBalance[msg.sender]) {
            revert exactBorrowedBalanceMustBeRepaid();
        }

        (bool success,) = address(this).call{value: amount}("");
        if (!success) {
            revert repaymentFailed();
        } else {
            borrowedBalance[msg.sender] = 0;
            emit UserRepaidBorrowedAmount(msg.sender, amount, address(this).balance);
        }
    }

    function rug() external onlyOwner {
        /**
         * Functionalities:
         * 1. Checks if msg.sender == owner
         * 2. Checks if contract address has a balance == 0
         * 3. Sends all funds inside of contract to the owner's address
         * 4. Emits safu() event
         *
         */
        if (address(this).balance == 0) {
            revert withdrawError();
        }
        (bool pulled,) = payable(msg.sender).call{value: address(this).balance}("");
        if (!pulled) {
            revert withdrawError();
        }
        emit safu();
    }

    function getDepositBalance(address _user) public view returns (uint256) {
        return depositBalance[_user];
    }

    function getBorrowedBalance(address _user) public view returns (uint256) {
        return borrowedBalance[_user];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwnerAddress() public view returns (address) {
        return i_owner;
    }
}
