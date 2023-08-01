// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
   function run() external returns (HelperConfig, Raffle) {
      HelperConfig helperConfig = new HelperConfig();

      (
         address vrfCoordinatorV2Address,
         bytes32 gasLane,
         uint64 subscriptionId,
         uint32 callbackGasLimit,
         uint256 entraceFee,
         uint256 interval
      ) = helperConfig.activeNetworkConfig();

      vm.startBroadcast();
      Raffle raffle = new Raffle(
         vrfCoordinatorV2Address,
         gasLane,
         subscriptionId,
         callbackGasLimit,
         entraceFee,
         interval
      );
      vm.stopBroadcast();

      return (helperConfig, raffle);
   }
}
