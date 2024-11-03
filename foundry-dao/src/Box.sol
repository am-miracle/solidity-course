// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    // event
    event NumberChanged(uint256 number);

    uint256 private s_number;

    constructor(uint256 initialNumber) Ownable(msg.sender) {
        s_number = initialNumber;
    }

    function setNumber(uint256 newNumber) external onlyOwner {
        s_number = newNumber;
        emit NumberChanged(newNumber);
    }

    function getNumber() external view returns (uint256) {
        return s_number;
    }
}
