// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";

contract RaffleTest is StdCheats, Test {
   event RequestedRaffleWinner(uint256 indexed requestId);
   event RaffleEnter(address indexed player);
   event WinnerPicked(address indexed player);

   Raffle public raffle;
   HelperConfig public helperConfig;

   uint64 subscriptionId;
   bytes32 gasLane;
   uint256 automationUpdateInterval;
   uint256 raffleEntranceFee;
   uint32 callbackGasLimit;
   address vrfCoordinatorV2;

   address public PLAYER = makeAddr("player");
   uint256 public constant STARTING_USER_BALANCE = 10 ether;

   function setUp() external {
      DeployRaffle deployer = new DeployRaffle();
      (helperConfig, raffle) = deployer.run();
      vm.deal(PLAYER, STARTING_USER_BALANCE);

      (
         vrfCoordinatorV2,
         gasLane,
         subscriptionId,
         callbackGasLimit,
         raffleEntranceFee,
         automationUpdateInterval,
         ,

      ) = helperConfig.activeNetworkConfig();
   }

   modifier raffleEntered() {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: raffleEntranceFee}();
      vm.warp(block.timestamp + automationUpdateInterval + 1);
      vm.roll(block.number + 1);
      _;
   }

   modifier onlyOnDeployedContracts() {
      if (block.chainid == 31337) {
         return;
      }
      try vm.activeFork() returns (uint256) {
         return;
      } catch {
         _;
      }
   }

   function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
      public
      raffleEntered
      onlyOnDeployedContracts
   {
      // Arrange
      // Act / Assert
      vm.expectRevert("nonexistent request");
      // vm.mockCall could be used here...
      VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(0, address(raffle));

      vm.expectRevert("nonexistent request");

      VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(1, address(raffle));
   }

   function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
      public
      raffleEntered
      onlyOnDeployedContracts
   {
      address expectedWinner = address(1);

      uint256 additionalEntrances = 3;
      uint256 startingIndex = 1;

      for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
         address player = address(uint160(i));
         hoax(player, 1 ether);
         raffle.enterRaffle{value: raffleEntranceFee}();
      }

      uint256 startingTimeStamp = raffle.getLatestTimestamp();
      uint256 startingBalance = expectedWinner.balance;

      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 requestId = entries[1].topics[1];

      VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
         uint256(requestId),
         address(raffle)
      );

      address recentWinner = raffle.getRecentWinner();
      Raffle.RaffleState raffleState = raffle.getRaffleState();
      uint256 winnerBalance = recentWinner.balance;
      uint256 endingTimeStamp = raffle.getLatestTimestamp();
      uint256 prize = raffleEntranceFee * (additionalEntrances + 1);

      assert(recentWinner == expectedWinner);
      assert(uint256(raffleState) == 0);
      assert(winnerBalance == startingBalance + prize);
      assert(endingTimeStamp > startingTimeStamp);
   }
}
