// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "../mock/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

contract RaffleTest is Test {
   Raffle public raffle;
   HelperConfig public helperConfig;

   address public vrfCoordinatorV2Address;
   bytes32 public gasLane;
   uint64 public subscriptionId;
   uint32 public callbackGasLimit;
   uint256 public entranceFee;
   uint256 public interval;

   address public PLAYER = makeAddr("player");
   uint256 public constant STARTING_USER_BALANCE = 10 ether;

   event RaffleEnter(address indexed player);
   event WinnerPicked(address indexed player);

   modifier raffleEntered() {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      _;
   }

   modifier timePassed() {
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
      _;
   }

   modifier skipFork() {
      if (block.chainid != 31337) {
         return;
      }

      _;
   }

   function setUp() external {
      DeployRaffle deployer = new DeployRaffle();
      (helperConfig, raffle) = deployer.run();

      vm.deal(PLAYER, STARTING_USER_BALANCE);

      (
         vrfCoordinatorV2Address,
         gasLane,
         subscriptionId,
         callbackGasLimit,
         entranceFee,
         interval,
         ,

      ) = helperConfig.activeNetworkConfig();
   }

   function testRaffleInitializesWithCorrectVrfCoordinatorV2Address() public view {
      assert(raffle.getVRFCoordinatorV2() == vrfCoordinatorV2Address);
   }

   function testRaffleInitializesInOpenState() public view {
      assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
   }

   function testRaffleRevertsWhenYouDontPayEnough() public {
      vm.prank(PLAYER);
      vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
      raffle.enterRaffle();
   }

   function testCantEnterWhenRaffleIsCalculating() public raffleEntered timePassed {
      raffle.performUpkeep("");
      vm.prank(PLAYER);
      vm.expectRevert(Raffle.Raffle__NotOpen.selector);
      raffle.enterRaffle{value: entranceFee}();
   }

   function testRaffleRecordsPlayerWhenTheyEnter() public raffleEntered {
      assert(raffle.getPlayer(0) == PLAYER);
   }

   function testEmitsEventOnEntrance() public {
      vm.prank(PLAYER);
      vm.expectEmit();
      emit RaffleTest.RaffleEnter(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
   }

   function testCheckUpkeepReturnsFalseIfItHasNoBalance() public timePassed {
      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      assert(!upkeepNeeded);
   }

   function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public raffleEntered timePassed {
      raffle.performUpkeep("");
      Raffle.RaffleState raffleState = raffle.getRaffleState();

      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      assert(raffleState == Raffle.RaffleState.CALCULATING);
      assert(!upkeepNeeded);
   }

   function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public raffleEntered {
      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      assert(!upkeepNeeded);
   }

   function testCheckUpkeepReturnsTrueWhenParametersAreGood() public raffleEntered timePassed {
      (bool upkeepNeeded, ) = raffle.checkUpkeep("");

      assert(upkeepNeeded);
   }

   function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered timePassed {
      raffle.performUpkeep("");
   }

   function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
      uint256 balance = address(raffle).balance;
      uint256 numPlayers = raffle.getLengthOfPlayers();
      Raffle.RaffleState raffleState = raffle.getRaffleState();
      vm.expectRevert(
         abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector,
            balance,
            numPlayers,
            raffleState
         )
      );
      raffle.performUpkeep("");
   }

   function testPerformUpkeepUpdatesRaffleState() public raffleEntered timePassed {
      raffle.performUpkeep("");

      assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
   }

   function testPerformUpkeepEmitsRequestId() public raffleEntered timePassed {
      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      (uint256 requestId, , , , ) = abi.decode(
         entries[0].data,
         (uint256, uint256, uint16, uint32, uint32)
      );

      assert(requestId > 0);
   }

   function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
      public
      raffleEntered
      timePassed
      skipFork
   {
      vm.expectRevert("nonexistent request");
      VRFCoordinatorV2Mock(vrfCoordinatorV2Address).fulfillRandomWords(0, address(raffle));
      vm.expectRevert("nonexistent request");
      VRFCoordinatorV2Mock(vrfCoordinatorV2Address).fulfillRandomWords(1, address(raffle));
   }

   function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney()
      public
      raffleEntered
      timePassed
      skipFork
   {
      address expectedWinner = address(1);

      uint256 additionalEntrances = 3;
      uint256 startingIndex = 1;

      for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
         address player = address(uint160(i));
         hoax(player, STARTING_USER_BALANCE);
         raffle.enterRaffle{value: entranceFee}();
      }

      uint256 startingTimeStamp = raffle.getLatestTimestamp();
      uint256 startingBalance = expectedWinner.balance;

      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      (uint256 requestId, , , , ) = abi.decode(
         entries[0].data,
         (uint256, uint256, uint16, uint32, uint32)
      );

      VRFCoordinatorV2Mock(vrfCoordinatorV2Address).fulfillRandomWords(
         uint256(requestId),
         address(raffle)
      );

      address recentWinner = raffle.getRecentWinner();
      Raffle.RaffleState raffleState = raffle.getRaffleState();
      uint256 winnerBalance = recentWinner.balance;
      uint256 endingTimeStamp = raffle.getLatestTimestamp();
      uint256 prize = entranceFee * (additionalEntrances + startingIndex);

      assert(recentWinner == expectedWinner);
      assert(uint256(raffleState) == 0);
      assert(winnerBalance == startingBalance + prize);
      assert(endingTimeStamp > startingTimeStamp);
   }
}
