// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IPrediction {

    struct PredictionMeta {
        uint256 index;
        string name;
        string description;
        uint256 endTime; // block.timestamp unit is second
        address admin; // prediction admin, only admin can reveal the prediction
        uint256 feeRatio; // ratio base is 1_000_000_000, 1_000_000_00 means 10%
        uint8 outcome;  // default is options.length, which means not revealed
        bool feeClaimed;
        string[] options;
        string[] optionLogos; // option logo urls
        uint256[] optionVotes;
    }

    event UserBet(uint256 indexed pId, address indexed user, uint256 indexed option, uint256 amount);

    event UserClaim(uint256 indexed pId, address indexed user, uint256 amount);

    event PredictionReveal(uint256 indexed pId, uint8 indexed outcome);

    event PredictionFeeClaim(uint256 indexed pId, address indexed admin, uint256 amount);

    function RATIO_BASE() external view returns (uint256);
    // total number of predictions
    function predictionIndex() external view returns (uint256);

    function getPrediction(uint256 pId) external view returns (PredictionMeta memory);

    function getUnfinishedPredictions() external view returns (PredictionMeta[] memory);

    function getPredictions() external view returns (PredictionMeta[] memory);

    function getPredictions(uint256 start, uint256 end) external view returns (PredictionMeta[] memory);

    function getPredictionTotalVotes(uint256 pId) external view returns (uint256);

    function bet(uint256 pId, uint8 option) external payable;

    function userBets(uint256 pId, address user) external view returns (uint256[] memory);

    function isUserClaimed(uint256 pId, address user) external view returns (bool);
    // the amount of user can claim
    function userClaimableAmount(uint256 pId, address user) external view returns (uint256);

    function claim(uint256 pId) external;
}