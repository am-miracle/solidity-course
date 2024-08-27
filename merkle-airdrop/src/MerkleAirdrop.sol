// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BagelToken} from "./BagelToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MerkleAirdrop {
    address[] claimer;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;

    constructor(bytes32 merkleRoot, IERC20 airdropToken) {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external {}
}
