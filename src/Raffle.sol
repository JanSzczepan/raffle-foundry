// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
   error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
   error Raffle__NotEnoughEth();
   error Raffle__NotOpen();
   error Raffle__TransferFailed();

   enum RaffleState {
      OPEN,
      CALCULATING
   }

   uint16 private constant REQUEST_CONFIRMATIONS = 3;
   uint32 private constant NUM_WORDS = 1;

   VRFCoordinatorV2Interface private immutable i_VRFCoordinatorV2;
   bytes32 private immutable i_gasLane;
   uint64 private immutable i_subscriptionId;
   uint32 private immutable i_callbackGasLimit;
   uint256 private immutable i_entraceFee;
   uint256 private immutable i_interval;

   RaffleState private s_raffleState;
   address payable[] private s_players;
   address private s_recentWinner;
   uint256 private s_latestTimestamp;

   event RaffleEnter(address indexed player);
   event WinnerPicked(address indexed player);

   constructor(
      address _VRFCoordinatorV2Address,
      bytes32 _gasLane,
      uint64 _subscriptionId,
      uint32 _callbackGasLimit,
      uint256 _entraceFee,
      uint256 _interval
   ) VRFConsumerBaseV2(_VRFCoordinatorV2Address) {
      i_VRFCoordinatorV2 = VRFCoordinatorV2Interface(_VRFCoordinatorV2Address);
      i_gasLane = _gasLane;
      i_subscriptionId = _subscriptionId;
      i_callbackGasLimit = _callbackGasLimit;
      i_entraceFee = _entraceFee;
      i_interval = _interval;
      s_raffleState = RaffleState.OPEN;
      s_latestTimestamp = block.timestamp;
   }

   function enterRaffle() public payable {
      if (msg.value < i_entraceFee) {
         revert Raffle__NotEnoughEth();
      }
      if (s_raffleState != RaffleState.OPEN) {
         revert Raffle__NotOpen();
      }

      s_players.push(payable(msg.sender));
      emit RaffleEnter(msg.sender);
   }

   function checkUpkeep(
      bytes memory /* checkData */
   ) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
      bool timeHasPassed = block.timestamp - s_latestTimestamp >= i_interval;
      bool hasPlayers = s_players.length > 0;
      bool hasBalance = address(this).balance > 0;
      bool isOpen = s_raffleState == RaffleState.OPEN;

      upkeepNeeded = timeHasPassed && hasPlayers && hasBalance && isOpen;

      return (upkeepNeeded, "0x0");
   }

   function performUpkeep(bytes calldata /* performData */) external override {
      (bool upkeepNeeded, ) = checkUpkeep("");

      if (!upkeepNeeded) {
         revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
      }

      s_raffleState = RaffleState.CALCULATING;

      i_VRFCoordinatorV2.requestRandomWords(
         i_gasLane,
         i_subscriptionId,
         REQUEST_CONFIRMATIONS,
         i_callbackGasLimit,
         NUM_WORDS
      );
   }

   function fulfillRandomWords(uint256 /* _requestId */, uint256[] memory _randomWords) internal override {
      address winner = s_players[_randomWords[0] % s_players.length];
      s_recentWinner = winner;
      s_players = new address payable[](0);
      s_raffleState = RaffleState.OPEN;
      s_latestTimestamp = block.timestamp;

      emit WinnerPicked(winner);

      (bool success, ) = winner.call{value: address(this).balance}("");

      if (!success) {
         revert Raffle__TransferFailed();
      }
   }

   function getRaffleState() external view returns (RaffleState) {
      return s_raffleState;
   }

   function getPlayer(uint256 _index) external view returns (address) {
      return s_players[_index];
   }

   function getLengthOfPlayers() external view returns (uint256) {
      return s_players.length;
   }

   function getRecentWinner() external view returns (address) {
      return s_recentWinner;
   }

   function getVRFCoordinatorV2() external view returns (address) {
      return address(i_VRFCoordinatorV2);
   }

   function getGasLane() external view returns (bytes32) {
      return i_gasLane;
   }

   function getSubscriptionId() external view returns (uint64) {
      return i_subscriptionId;
   }

   function getCallbackGasLimit() external view returns (uint32) {
      return i_callbackGasLimit;
   }

   function getEntranceFee() external view returns (uint256) {
      return i_entraceFee;
   }

   function getInterval() external view returns (uint256) {
      return i_interval;
   }

   function getRequestConfirmations() external pure returns (uint16) {
      return REQUEST_CONFIRMATIONS;
   }

   function getNumWords() external pure returns (uint32) {
      return NUM_WORDS;
   }
}
