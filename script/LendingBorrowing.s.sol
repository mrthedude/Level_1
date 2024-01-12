// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {basicLendingBorrowing} from "../src/LendingBorrowing.sol";

contract deployer is Script {
    function run() external returns (basicLendingBorrowing) {
        vm.startBroadcast();
        basicLendingBorrowing lendingContract = new basicLendingBorrowing();
        vm.stopBroadcast();
        return lendingContract;
    }
}
