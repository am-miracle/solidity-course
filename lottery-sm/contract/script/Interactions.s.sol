// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/dev/vrf/SubscriptionAPI.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubcription is Script {
    function createSubcriptionConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ) = helperConfig
            .activeNetworkConfig();

        return createSubcription(vrfCoordinator);
    }

    function createSubcription(
        address vrfCoordinator
    ) public returns (uint256) {
        console.log("Creating subscription on chain", block.chainid);

        vm.startBroadcast();
        uint256 subId = SubscriptionAPI(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subId is: ", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint256) {
        return createSubcriptionConfig();
    }
}

contract FundSubcription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint256 subId,
            ,
            address link
        ) = helperConfig.activeNetworkConfig();

        return fundSubscription(vrfCoordinator, subId, link);
    }

    function fundSubscription(
        address vrfCoordinatorV2,
        uint256 subId,
        address link
    ) public returns (uint256) {
        console.log("Funding subscription on chain: ", block.chainid);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2);
        console.log("On chainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast();
            SubscriptionAPI(vrfCoordinatorV2).fundSubscriptionWithEth{
                value: FUND_AMOUNT
            }(subId);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external returns (uint256) {
        return fundSubscriptionConfig();
    }
}
