// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployBasicNFT} from "../script/DeployBasicNFT.s.sol";
import {BasicNFT} from "../src/BasicNFT.sol";

contract BasicNftTest is Test {
    string constant NFT_NAME = "Basic";
    string constant NFT_SYMBOL = "BAS";
    string public constant PUG_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    DeployBasicNFT public deployer;
    BasicNFT basicNft;

    address public USER = makeAddr("user");

    function setUp() public {
        deployer = new DeployBasicNFT();
        basicNft = deployer.run();
    }

    function testIsNameCorrect() public view {
        // Arrange
        string memory actualName = basicNft.name();
        // Act / Assert
        assert(
            keccak256(abi.encodePacked(NFT_NAME)) ==
                keccak256(abi.encodePacked(actualName))
        );
    }

    function testCanMintAndHaveBalance() public {
        // Arrange
        vm.prank(USER);
        basicNft.mintNFT(PUG_URI);

        // Act / Assert
        assert(basicNft.balanceOf(USER) == 1);
        assert(
            keccak256(abi.encodePacked(PUG_URI)) ==
                keccak256(abi.encodePacked(basicNft.tokenURI(0)))
        );
    }
}
