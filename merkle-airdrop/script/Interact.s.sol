// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract ClaimAirdrop is Script {
    error ClaimAirdrop_InvalidSignatureLength();

    address CLAIMING_ACCOUNT = 0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D;
    uint256 CLAIMGING_AMOUNT = 25 * 1e18;
    bytes32 proofOne = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [proofOne, proofTwo];
    bytes private SIGNATURE =
        hex"2034686ed346ba800045624b714fb9462285709763f52c71f866d73220d2a8ce7a3ee0455fe1e91677c3778d7d397169332d8c559eb517b331d674009b4e69f01c";

    // 0: contract MerkleAirdrop 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
    // call : 0x7ba5b7b6db266268fbafec1668550626e2a28b36bc90cfa48c53e1d0bd3c559c
    // has : 2034686ed346ba800045624b714fb9462285709763f52c71f866d73220d2a8ce7a3ee0455fe1e91677c3778d7d397169332d8c559eb517b331d674009b4e69f01c
    function claimAirdrop(address airdrop) public {
        vm.startBroadcast();
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(airdrop).claim(CLAIMING_ACCOUNT, CLAIMGING_AMOUNT, PROOF, v, r, s);
        vm.stopBroadcast();
    }

    function splitSignature(bytes memory sig) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (sig.length != 65) {
            revert ClaimAirdrop_InvalidSignatureLength();
        }
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function run() external {
        address getMostRecentDeployment = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        claimAirdrop(getMostRecentDeployment);
    }
}
