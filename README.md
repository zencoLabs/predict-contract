# prediction-smart-contract

This is a smart contract for a prediction dApp.

## How to deploy

Prerequisite:

1. git
2. node.js

To deploy it, follow these steps:

1. Clone the code, and install the dependencies: `git clone xxx && cd prediction-smart-contract && npm install`
2. Copy the `env.example` file to `.env`, and fill in the `PRIVATE_KEY` value, this is the deploy account private key.
3. Compile the contract: `npx hardhat compile`
4. Deploy the contract: `npx hardhat ignition deploy ./ignition/modules/Prediction.ts --network xxxx`

Make sure you `have enough balance` in the deploy account to pay for the gas fee in `xxxx` network. You can add one network by editing file `hardhat.confg.ts`

## How to add a prediction

Anyone can add a prediction by invoke method:

```solidity
function createPrediction(
    string memory name, 
    string memory description, 
    string[] memory options, 
    string[] memory optionLogos,  // option logo urls
    uint256 endTime,  // timestamp in seconds
    uint256 feeRatio  // ratio base is 1_000_000_000, 1_000_000_00 means 10%
)
```

Notes:

1. The options.length should equal optionLogos.length, max value is 10
2. The creator will automatically become this prediction admin
3. Admin can reveal the prediction when it's finished by call `revealPrediction(uint256 pId, uint8 outcome)`
4. The `endTime` should be a future timestamp
5. The `feeRatio` base is `1_000_000_000`, which means if you want set the real fee ratio to 10%, `feeRatio` should be set `1_000_000_000 / 10`

Note: The prediction options index is start from 0, so the `outcome` should be in the range of `[0, options.length)`

## How to bet

Anyone can bet any prediction option by put their CFX/ETH. The overall flow are:

1. Use `predictionIndex()` to get the max prediction index, use `getPrediction(uint256 pId)` to get one prediction metadata.
2. `getUnfinishedPredictions()` `getPredictions()` `getPredictions(uint256 start, uint256 end)` can be used to get multi predictions
3. Bet prediction option through calling method `bet(uint256 pId, uint8 option)`, bet amount is specified by tx.value
4. Method `userBets(uint256 pId, address user) returns (uint256[] memory)` to get user bets.
5. Method `userClaimableAmount(uint256 pId, address user) returns (uint256)` to get claimable amount.
6. Claim reward by call `claim(uint256 pId)`

Check the [`IPrediction interface`](./contracts/IPrediction.sol) for details

## Note

> This contract has not been audit, use it at your own risk.

## Hardhat commands

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```
