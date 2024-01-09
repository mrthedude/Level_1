// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {basicLendingBorrowing} from "../src/LendingBorrowing.sol";

contract deployer is Script {
    function run() external returns (basicLendingBorrowing) {
        basicLendingBorrowing lendingContract = new basicLendingBorrowing();

        return lendingContract;
    }
}
