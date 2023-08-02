// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
   function run() external returns (HelperConfig, Raffle) {
      HelperConfig helperConfig = new HelperConfig();
      AddConsumer addConsumer = new AddConsumer();

      (
         address vrfCoordinatorV2Address,
         bytes32 gasLane,
         uint64 subscriptionId,
         uint32 callbackGasLimit,
         uint256 entraceFee,
         uint256 interval,
         address link,
         uint256 deployerKey
      ) = helperConfig.activeNetworkConfig();

      if (subscriptionId == 0) {
         CreateSubscription createSubscription = new CreateSubscription();
         subscriptionId = createSubscription.createSubscription(vrfCoordinatorV2Address, deployerKey);

         FundSubscription fundSubscription = new FundSubscription();
         fundSubscription.fundSubscription(vrfCoordinatorV2Address, subscriptionId, link, deployerKey);
      }

      vm.startBroadcast(deployerKey);
      Raffle raffle = new Raffle(
         vrfCoordinatorV2Address,
         gasLane,
         subscriptionId,
         callbackGasLimit,
         entraceFee,
         interval
      );
      vm.stopBroadcast();

      addConsumer.addConsumer(vrfCoordinatorV2Address, subscriptionId, address(raffle), deployerKey);

      return (helperConfig, raffle);
   }
}
