// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
   struct NetworkConfig {
      address vrfCoordinatorV2Address;
      bytes32 gasLane;
      uint64 subscriptionId;
      uint32 callbackGasLimit;
      uint256 entraceFee;
      uint256 interval;
   }

   NetworkConfig public activeNetworkConfig;

   event HelperConfig__CreatedMockVRFCoordinator(address vrfCoordinator);

   constructor() {
      if (block.chainid == 11155111) {
         activeNetworkConfig = getSepoliaNetworkConfig();
      } else {
         activeNetworkConfig = getOrCreateAnvilNetworkConfig();
      }
   }

   function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
      if (activeNetworkConfig.vrfCoordinatorV2Address != address(0)) {
         return activeNetworkConfig;
      }

      uint96 baseFee = 0.25 ether;
      uint96 gasPriceLink = 1e9;

      vm.startBroadcast();
      VRFCoordinatorV2Mock vrfCoordinatoV2Mock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
      vm.stopBroadcast();

      emit HelperConfig__CreatedMockVRFCoordinator(address(vrfCoordinatoV2Mock));

      anvilNetworkConfig = NetworkConfig({
         vrfCoordinatorV2Address: address(vrfCoordinatoV2Mock),
         gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
         subscriptionId: 0,
         callbackGasLimit: 500000,
         entraceFee: 0.1 ether,
         interval: 60
      });
   }

   function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
      sepoliaNetworkConfig = NetworkConfig({
         vrfCoordinatorV2Address: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
         gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
         subscriptionId: 0,
         callbackGasLimit: 500000,
         entraceFee: 0.1 ether,
         interval: 60
      });
   }
}
