// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";

contract CreateSubscription is Script {
   function createSubscription(address vrfCoordinatorAddress) public returns (uint64) {
      console.log("Creating subscription on chainId: ", block.chainid);

      vm.startBroadcast();
      uint64 subId = VRFCoordinatorV2Mock(vrfCoordinatorAddress).createSubscription();
      vm.stopBroadcast();

      console.log("Your subscription Id is: ", subId);
      console.log("Please update the subscriptionId in HelperConfig.s.sol");

      return subId;
   }

   function createSubscriptionUsingConfig() internal returns (uint64) {
      HelperConfig helperConfig = new HelperConfig();
      (address vrfCoordinatorV2Address, , , , , ) = helperConfig.activeNetworkConfig();

      return createSubscription(vrfCoordinatorV2Address);
   }

   function run() external returns (uint64) {
      return createSubscriptionUsingConfig();
   }
}
