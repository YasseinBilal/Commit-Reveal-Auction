// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CommitRevealAuction} from "../src/CommitRevealAuction.sol";

contract DeployCommitRevealAuction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        CommitRevealAuction auction = new CommitRevealAuction();

        vm.stopBroadcast();

        console.log("CommitRevealAuction deployed at:", address(auction));
    }
}
