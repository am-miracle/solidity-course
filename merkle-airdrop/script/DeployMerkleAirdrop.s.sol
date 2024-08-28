// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BagelToken} from "../src//BagelToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Script} from "forge-std/Script.sol";

contract DeployMerkleAirdrop is Script {
    uint256 public s_amountToTransfer = 4 * 25 * 1e18;
    bytes32 public s_merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;

    function deployMerkleRoot() public returns (MerkleAirdrop, BagelToken) {
        vm.startBroadcast();

        BagelToken bagelToken = new BagelToken();
        MerkleAirdrop merkleAirdrop = new MerkleAirdrop(s_merkleRoot, IERC20(address(bagelToken)));
        // mint token
        bagelToken.mint(bagelToken.owner(), s_amountToTransfer);
        // transfer token to merkle airdrop
        bagelToken.transfer(address(merkleAirdrop), s_amountToTransfer);
        vm.stopBroadcast();
        return (merkleAirdrop, bagelToken);
    }

    function run() external returns (MerkleAirdrop, BagelToken) {
        return deployMerkleRoot();
    }
}
