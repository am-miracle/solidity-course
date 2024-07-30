// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {BasicNFT} from "../src/BasicNFT.sol";
import {MoodNft} from "../src/MoodNft.sol";
import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract MintBasicNft is Script {
    string public constant PUG_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "BasicNFT",
            block.chainid
        );

        mintOnContract(mostRecentlyDeployed);
    }

    function mintOnContract(address contractAddress) public {
        vm.startBroadcast();
        BasicNFT(contractAddress).mintNFT(PUG_URI);
        vm.stopBroadcast();
    }
}

contract MintMoodNft is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "MoodNft",
            block.chainid
        );
        mintOnContract(mostRecentlyDeployed);
    }

    function mintOnContract(address contractAddress) public {
        vm.startBroadcast();
        MoodNft(contractAddress).mintNft();
        vm.stopBroadcast();
    }
}

contract FlipMoodNft is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "MoodNft",
            block.chainid
        );
        flipMoodOnContract(mostRecentlyDeployed);
    }

    function flipMoodOnContract(address contractAddress) public {
        vm.startBroadcast();
        MoodNft(contractAddress).flipMood(0);
        vm.stopBroadcast();
    }
}
