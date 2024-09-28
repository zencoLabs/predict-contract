// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import { IPrediction } from "./IPrediction.sol";

contract Prediction is IPrediction {
    uint256 public constant RATIO_BASE = 1_000_000_000;

    uint256 public predictionIndex; // next prediction index, also the number of predictions, starts at 0 

    mapping(uint256 => PredictionMeta) private _predictions;

    mapping(uint256 => mapping(address => uint256[])) private _userBets; // predictionIndex => user => amounts
    mapping(uint256 => mapping(address => bool)) private _userClaimed; // predictionIndex => user => claimed

    modifier onlyOwner(uint256 pIndex) {
        require(msg.sender == _predictions[pIndex].admin, "Not owner");
        _;
    }

    modifier onlyFinished(uint256 pIndex) {
        require(block.timestamp > _predictions[pIndex].endTime, "Prediction is not over yet");
        _;
    }

    modifier onlyUnFinished(uint256 pIndex) {
        require(block.timestamp <= _predictions[pIndex].endTime, "Prediction is over");
        _;
    }

    modifier onlyValidIndex(uint256 pIndex) {
        require(pIndex < predictionIndex, "Prediction does not exist");
        _;
    }

    function _totalVotes(uint256[] memory votes) private pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < votes.length; i++) {
            total += votes[i];
        }
        return total;    
    }

    // total user share of the prediction
    function _totalUserShare(uint256[] memory votes, uint256 feeRatio) private pure returns (uint256) {
        uint256 total = _totalVotes(votes);
        uint256 fee = total * feeRatio / RATIO_BASE;
        return total - fee;
    }

    constructor() {

    }

    function bet(uint256 pId, uint8 option) public payable onlyValidIndex(pId)  onlyUnFinished(pId) {
        require(msg.value > 0, "Value must be greater than 0");
        require(msg.value % 1 ether == 0, "Value must be multiple of 1 ether");
        uint256 opLen = _predictions[pId].options.length;
        require(option < opLen, "Invalid option");
        _predictions[pId].optionVotes[option] += msg.value;
        
        if (_userBets[pId][msg.sender].length == 0) {
            _userBets[pId][msg.sender] = new uint256[](opLen);
        }
        _userBets[pId][msg.sender][option] += msg.value;

        emit UserBet(pId, msg.sender, option, msg.value);
    }

    function userBets(uint256 pId, address user) public view onlyValidIndex(pId) returns (uint256[] memory) {
        uint256[] memory uBets = _userBets[pId][user];
        if (uBets.length == 0) {
            uBets = new uint256[](_predictions[pId].options.length);
        }
        return uBets;
    }

    function isUserClaimed(uint256 pId, address user) public view  onlyValidIndex(pId) returns (bool) {
        return _userClaimed[pId][user];
    }

    function userClaimableAmount(uint256 pId, address user) external view returns (uint256) {
        PredictionMeta memory prediction = _predictions[pId];
        uint8 outcome = prediction.outcome;
        if (outcome >= prediction.options.length) {
            return 0;
        }
        uint256 userValidBets = _userBets[pId][user][outcome];
        if (userValidBets == 0) {
            return 0;
        }
        if (_userClaimed[pId][user]) {
            return 0;
        }
        uint256 totalShare = _totalUserShare(prediction.optionVotes, prediction.feeRatio);
        return totalShare * userValidBets / prediction.optionVotes[outcome];
    }

    function claim(uint256 pId) public onlyValidIndex(pId) onlyFinished(pId) {
        PredictionMeta memory prediction = _predictions[pId];
        uint8 outcome = prediction.outcome;
        require(outcome < prediction.options.length, "Outcome not revealed");
        require(!_userClaimed[pId][msg.sender], "Already claimed");
        
        uint256 userValidBets = _userBets[pId][msg.sender][outcome];
        require(userValidBets > 0, "No bets placed");

        _userClaimed[pId][msg.sender] = true;
        
        uint256 totalShare = _totalUserShare(prediction.optionVotes, prediction.feeRatio);
        uint256 userShare =  totalShare * userValidBets / prediction.optionVotes[outcome];
        
        payable(msg.sender).transfer(userShare);

        emit UserClaim(pId, msg.sender, userShare);
    }

    function createPrediction(string memory name, string memory description, string[] memory options, string[] memory optionLogos, uint256 endTime, uint256 feeRatio) public {
        require(endTime > block.timestamp, "End time must be in the future");
        require(feeRatio < RATIO_BASE, "Fee ratio must be less than to 100%");
        uint8 oLen = uint8(options.length);
        require(oLen >= 2 && oLen <= 10, "options should between 2-10");
        require(oLen == optionLogos.length, "options and optionLogos should have the same length");

        uint256 index = predictionIndex++;

        PredictionMeta memory prediction = PredictionMeta({
            index: index,
            name: name,
            description: description,
            options: options,
            optionLogos: optionLogos,
            optionVotes: new uint256[](oLen),
            endTime: endTime,
            admin: msg.sender,
            feeRatio: feeRatio,
            outcome: oLen,
            feeClaimed: false
        });

        _predictions[index] = prediction;
    }

    function revealPrediction(uint256 pId, uint8 outcome) public onlyValidIndex(pId) onlyOwner(pId) onlyFinished(pId) {
        require(outcome < _predictions[pId].options.length, "Invalid outcome");
        PredictionMeta storage prediction = _predictions[pId];
        prediction.outcome = outcome;

        emit PredictionReveal(pId, outcome);
    }

    function claimPredictionFee(uint256 pId) public onlyValidIndex(pId) onlyOwner(pId) onlyFinished(pId)  {
        PredictionMeta storage prediction = _predictions[pId];
        require(!prediction.feeClaimed, "Fee already claimed");
        prediction.feeClaimed = true;
        
        if (prediction.feeRatio > 0) {
            uint256 fee = _totalVotes(prediction.optionVotes) * prediction.feeRatio / RATIO_BASE;
            payable(msg.sender).transfer(fee);

            emit PredictionFeeClaim(pId, msg.sender, fee);
        }
    }

    function getPrediction(uint256 pId) public onlyValidIndex(pId) view returns (PredictionMeta memory) {
        return _predictions[pId];
    }

    function getPredictionTotalVotes(uint256 pId) public view returns (uint256) {
        return _totalVotes(_predictions[pId].optionVotes);
    }

    function getPredictions() public view returns (PredictionMeta[] memory) {
        PredictionMeta[] memory predictions = new PredictionMeta[](predictionIndex);
        for (uint256 i = 0; i < predictionIndex; i++) {
            predictions[i] = _predictions[i];
        }
        return predictions;
    }

    function getUnfinishedPredictions() public view returns (PredictionMeta[] memory) {
        PredictionMeta[] memory predictions = new PredictionMeta[](predictionIndex);
        uint256 count = 0;
        for (uint256 i = 0; i < predictionIndex; i++) {
            if (_predictions[i].endTime > block.timestamp) {
                predictions[count] = _predictions[i];
                count++;
            }
        }
        assembly {
            mstore(predictions, count)
        }
        return predictions;
    }

    function getPredictions(uint256 start, uint256 end) public view returns (PredictionMeta[] memory) {
        require(start < end, "Start must be less than end");
        require(end <= predictionIndex, "End must be less than or equal to the number of _predictions");

        PredictionMeta[] memory predictions = new PredictionMeta[](end - start);
        for (uint256 i = start; i < end; i++) {
            predictions[i] = _predictions[i];
        }
        return predictions;
    }
}