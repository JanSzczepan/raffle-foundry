// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../test/mock/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract HelperConfig is Script {
   struct NetworkConfig {
      address vrfCoordinatorV2Address;
      bytes32 gasLane;
      uint64 subscriptionId;
      uint32 callbackGasLimit;
      uint256 entraceFee;
      uint256 interval;
      address link;
      uint256 deployerKey;
   }

   NetworkConfig public activeNetworkConfig;
   uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
      0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

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
      LinkToken link = new LinkToken();
      vm.stopBroadcast();

      emit HelperConfig__CreatedMockVRFCoordinator(address(vrfCoordinatoV2Mock));

      anvilNetworkConfig = NetworkConfig({
         vrfCoordinatorV2Address: address(vrfCoordinatoV2Mock),
         gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
         subscriptionId: 0,
         callbackGasLimit: 500000,
         entraceFee: 0.1 ether,
         interval: 60,
         link: address(link),
         deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
      });
   }

   function getSepoliaNetworkConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
      sepoliaNetworkConfig = NetworkConfig({
         vrfCoordinatorV2Address: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
         gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
         subscriptionId: 0,
         callbackGasLimit: 500000,
         entraceFee: 0.1 ether,
         interval: 60,
         link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
         deployerKey: vm.envUint("PRIVATE_KEY")
      });
   }
}
