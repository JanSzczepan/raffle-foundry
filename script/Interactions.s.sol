// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract CreateSubscription is Script {
   function createSubscription(address _vrfCoordinatorV2Address, uint256 _deployerKey) public returns (uint64) {
      console.log("Creating subscription on chainId: ", block.chainid);

      vm.startBroadcast(_deployerKey);
      uint64 subId = VRFCoordinatorV2Mock(_vrfCoordinatorV2Address).createSubscription();
      vm.stopBroadcast();

      console.log("Your subscription Id is: ", subId);
      console.log("Please update the subscriptionId in HelperConfig.s.sol");

      return subId;
   }

   function createSubscriptionUsingConfig() internal returns (uint64) {
      HelperConfig helperConfig = new HelperConfig();
      (address vrfCoordinatorV2Address, , , , , , , uint256 deployerKey) = helperConfig.activeNetworkConfig();

      return createSubscription(vrfCoordinatorV2Address, deployerKey);
   }

   function run() external returns (uint64) {
      return createSubscriptionUsingConfig();
   }
}

contract AddConsumer is Script {
   function addConsumer(
      address _vrfCoordinatorV2Address,
      uint64 _subId,
      address _consumer,
      uint256 _deployerKey
   ) public {
      console.log("Adding consumer contract: ", _consumer);
      console.log("Using vrfCoordinator: ", _vrfCoordinatorV2Address);
      console.log("On ChainID: ", block.chainid);

      vm.startBroadcast(_deployerKey);
      VRFCoordinatorV2Mock(_vrfCoordinatorV2Address).addConsumer(_subId, _consumer);
      vm.stopBroadcast();
   }

   function addConsumerUsingConfig(address _raffleAddress) internal {
      HelperConfig helperConfig = new HelperConfig();
      (address vrfCoordinatorV2Address, , uint64 subId, , , , , uint256 deployerKey) = helperConfig
         .activeNetworkConfig();
      addConsumer(vrfCoordinatorV2Address, subId, _raffleAddress, deployerKey);
   }

   function run() external {
      address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
      addConsumerUsingConfig(mostRecentlyDeployed);
   }
}

contract FundSubscription is Script {
   uint96 public constant FUND_AMOUNT = 3 ether;

   function fundSubscription(
      address _vrfCoordinatorV2Address,
      uint64 _subId,
      address _link,
      uint256 _deployerKey
   ) public {
      console.log("Funding subscription: ", _subId);
      console.log("Using vrfCoordinator: ", _vrfCoordinatorV2Address);
      console.log("On ChainID: ", block.chainid);

      if (block.chainid == 31337) {
         vm.startBroadcast(_deployerKey);
         VRFCoordinatorV2Mock(_vrfCoordinatorV2Address).fundSubscription(_subId, FUND_AMOUNT);
         vm.stopBroadcast();
      } else {
         console.log(LinkToken(_link).balanceOf(msg.sender));
         console.log(msg.sender);
         console.log(LinkToken(_link).balanceOf(address(this)));
         console.log(address(this));

         vm.startBroadcast(_deployerKey);
         LinkToken(_link).transferAndCall(_vrfCoordinatorV2Address, FUND_AMOUNT, abi.encode(_subId));
         vm.stopBroadcast();
      }
   }

   function fundSubscriptionUsingConfig() internal {
      HelperConfig helperConfig = new HelperConfig();
      (address vrfCoordinatorV2Address, , uint64 subId, , , , address link, uint256 deployerKey) = helperConfig
         .activeNetworkConfig();
      fundSubscription(vrfCoordinatorV2Address, subId, link, deployerKey);
   }

   function run() external {}
}
