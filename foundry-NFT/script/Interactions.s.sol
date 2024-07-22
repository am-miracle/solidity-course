// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {BasicNFT} from "../src/BasicNFT.sol";
import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract Interactions is Script {

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "BasicNFT",
            block.chainid
        );
        mintA
    }
}
