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

    address internal immutable i_owner;
    uint256 constant MAXIMUMCOLLATERALRATIO = 1.5e18; // LTV Ratio of 150%
    mapping(address user => uint256 amount) internal depositBalance;
    mapping(address user => uint256 amount) internal borrowedBalance;

    event UserDepositedFunds(address indexed user, uint256 indexed depositAmount);
    event UserWithdrewDeposit(address indexed user, uint256 withdrawAmount, uint256 indexed remainingDepositBalance);
    event UserBorrowedFunds(address indexed user, uint256 indexed borrowAmount, uint256 indexed totalBorrowAmount);
    event UserRepaidBorrowedAmount(address indexed user, uint256 repaymentAmount, uint256 indexed totalContractBalance);
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
        if (msg.value == 0) {
            revert noFundsDeposited();
        }

        depositBalance[msg.sender] += msg.value;
        emit UserDepositedFunds(msg.sender, depositBalance[msg.sender]);
    }

    function withdraw(uint256 amountInWei) external {
        /**
         * Functionalities:
         * 1. Checks to see if the withdraw amountInWei > depositBalance[msg.sender]
         * 2. Checks to see if user has an open lending position -> `borrowedBalance[msg.sender]`
         * 3. Sends the amountInWei to the user's address
         * 4. subtracts the user's depositBalance by the amountInWei
         * 5. Emits an event for a user withdrawing their deposit
         * DONE
         */
        if (amountInWei > depositBalance[msg.sender]) {
            revert cantWithdrawMoreThanDeposited();
        }

        if (borrowedBalance[msg.sender] != 0) {
            revert cannotWithdrawWhileFundsAreBorrowed();
        }

        (bool success,) = payable(msg.sender).call{value: amountInWei}("");
        if (!success) {
            revert withdrawError();
        }
        depositBalance[msg.sender] -= amountInWei;
        emit UserWithdrewDeposit(msg.sender, amountInWei, depositBalance[msg.sender]);
    }

    function borrow(uint256 amountInWei) external {
        /**
         * Functionalities:
         * 1. Checks to see if user has deposited funds
         * 2. Checks to see if borrowing the amountInWei will cause the user's LTV ratio to exceed the MAXIMUMCOLLATERALRATIO
         * 3. Checks to see if the contract has that amountInWei of ETH to lend
         * 4. Increases the user's borrowedBalance by the amountInWei
         * 5. Sends ETH amountInWei to user's address
         * 6. Emits borrow event
         * DONE
         */
        if (depositBalance[msg.sender] == 0) {
            revert noFundsDeposited();
        }

        if (((amountInWei + borrowedBalance[msg.sender]) * 1e18) / depositBalance[msg.sender] > MAXIMUMCOLLATERALRATIO)
        {
            revert borrowingAmountExceedsCollateralLTVRequirements();
        }

        if (address(this).balance < amountInWei) {
            revert notEnoughEthInContractToLend();
        }
        (bool success,) = payable(msg.sender).call{value: amountInWei}("");
        if (!success) {
            revert borrowingFailed();
        }
        borrowedBalance[msg.sender] += amountInWei;
        emit UserBorrowedFunds(msg.sender, amountInWei, borrowedBalance[msg.sender]);
    }

    function repay() external payable {
        /**
         * Functionalities:
         * 1. Reverts if repayment amountInWei != borrowedBalance
         * 2. Receives msg.value
         * 3. Sets borrowedBalance[msg.sender] = 0
         * 4. Emits event for repayment
         * DONE
         */
        if (msg.value != borrowedBalance[msg.sender]) {
            revert exactBorrowedBalanceMustBeRepaid();
        }

        borrowedBalance[msg.sender] = 0;
        emit UserRepaidBorrowedAmount(msg.sender, msg.value, address(this).balance);
    }

    function rug() external onlyOwner {
        /**
         * Functionalities:
         * 1. Checks if msg.sender == owner
         * 2. Checks if contract address has a balance == 0
         * 3. Emits safu() event
         * 4. Destroys the contract and sends all funds to i_owner
         * DONE
         */
        if (address(this).balance == 0) {
            revert withdrawError();
        }
        emit safu();
        selfdestruct(payable(i_owner));
    }

    function getDepositBalance(address _user) public view returns (uint256) {
        return depositBalance[_user];
    }

    function getBorrowedBalance(address _user) public view returns (uint256) {
        return borrowedBalance[_user];
    }
}
