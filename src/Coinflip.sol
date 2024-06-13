// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract CoinFlip is VRFV2PlusWrapperConsumerBase {
    event CoinFlipRequest(uint256 requestId);
    event CoinFlipResult(uint256 requestId, bool didWin);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    struct CoinFlipStatus {
        uint256 fees;
        uint256 randomWord;
        address player;
        bool didWin;
        bool fulfilled;
        CoinFlipSelection choice;
    }

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }

    enum CoinFlipSelection {
        HEADS,
        TAILS
    }

    mapping(uint256 => CoinFlipStatus) public statuses;
    mapping(uint256 => RequestStatus) public s_requests;

    // Address LINK - hardcoded for Fuji
    address public linkAddress = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    // Address WRAPPER - hardcoded for Fuji
    address public vrfWrapperAddress =
        0x327B83F409E1D5f13985c6d0584420FA648f1F56;

    uint128 constant entryFee = .01 ether;
    uint32 constant callbackGasLimit = 1000000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 3;

    constructor() payable VRFV2PlusWrapperConsumerBase(vrfWrapperAddress) {}

    function flip(CoinFlipSelection choice) external payable returns (uint256) {
        require(msg.value == entryFee, "Must pay entry fee");
        bool enableNativePayment = true;
        uint256 requestId;
        uint256 reqPrice;

        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
        (requestId, reqPrice) = requestRandomnessPayInNative(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extraArgs
        );

        statuses[requestId] = CoinFlipStatus({
            fees: reqPrice,
            randomWord: 0,
            player: msg.sender,
            didWin: false,
            fulfilled: false,
            choice: choice
        });

        emit CoinFlipRequest(requestId);
        return (requestId);
    }
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // require(s_requests[_requestId].paid > 0, "request not found");
        // s_requests[_requestId].fulfilled = true;
        // s_requests[_requestId].randomWords = _randomWords;
        // emit RequestFulfilled(
        //     _requestId,
        //     _randomWords,
        //     s_requests[_requestId].paid
        // );
        require(statuses[requestId].fees > 0, "request not found");

        statuses[requestId].fulfilled = true;
        statuses[requestId].randomWord = randomWords[0];

        CoinFlipSelection result = CoinFlipSelection.HEADS;
        if (randomWords[0] % 2 == 0) {
            result = CoinFlipSelection.TAILS;
        }

        if (statuses[requestId].choice == result) {
            statuses[requestId].didWin = true;
            payable(statuses[requestId].player).transfer(entryFee * 2);
        }

        emit CoinFlipResult(requestId, statuses[requestId].didWin);
    }

    function getStatus(
        uint256 requestId
    ) public view returns (CoinFlipStatus memory) {
        return statuses[requestId];
    }
}
