import { expect } from "chai";
import hre from "hardhat";
import {
    time,
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("Prediction", function () {
    async function deployPredictionFixture() {
      // Contracts are deployed using the first signer/account by default
      const [owner, otherAccount] = await hre.ethers.getSigners();
  
      const Prediction = await hre.ethers.getContractFactory("Prediction");
      const prediction = await Prediction.deploy();

      const ONE_HOUR_IN_SECS = 60 * 60;

      const name = "Test Prediction";
      const description = "Test Description";
      const options = ["Option 1", "Option 2"];
      const optionLogos = ["Option 1 Logo", "Option 2 Logo"];
      const unlockTime = (await time.latest()) + ONE_HOUR_IN_SECS;
      const feeRatio = 1000_000_00n; // 10%
      await prediction.createPrediction(name, description, options, optionLogos, unlockTime, feeRatio);
  
      return { 
        prediction, 
        owner, 
        otherAccount, 
        unlockTime, 
        name, 
        description, 
        options, 
        optionLogos, 
        feeRatio,
        index: 0,
        ONE_HOUR_IN_SECS,
      };
    }
  
    describe("Create", function () {
      it("Should create prediction", async function () {
        const { prediction, name, description, options, index } = await loadFixture(deployPredictionFixture);
  
        expect(await prediction.predictionIndex()).to.equal(1);

        const first = await prediction.getPrediction(index);
        expect(first.name).to.equal(name);
        expect(first.description).to.equal(description);
        expect(first.options.length).to.equal(options.length);

        const list = await prediction['getPredictions()']();
        expect(list.length).to.equal(1);
        expect(list[0].optionVotes.length).to.equal(options.length);
      });

      it("should reveal fail if prediction is not finished", async function () {
        const { prediction } = await loadFixture(deployPredictionFixture);
        await expect(prediction.revealPrediction(0, 0)).to.be.revertedWith("Prediction is not over yet");
      });

      it("should bet success", async function() {
        const { prediction, index, options, owner, otherAccount, unlockTime, feeRatio } = await loadFixture(deployPredictionFixture);

        let bets = await prediction.userBets(index, owner.address);
        expect(bets.length).to.equal(options.length);
        expect(bets.reduce((acc, option, _) => acc + option, 0n)).to.equal(0);

        // user1 bet
        const bet1Option = 0;
        const bet1Value = 1000n;
        let tx = await prediction.bet(index, bet1Option, { value: bet1Value });
        await tx.wait();
        
        let totalBet = await prediction.getPredictionTotalVotes(index);;
        expect(totalBet).to.equal(bet1Value);

        bets = await prediction.userBets(index, owner.address);
        expect(bets.length).to.equal(options.length);
        expect(bets[bet1Option]).to.equal(bet1Value);

        // user2 bet
        const bet2Option = 1;
        const bet2Value = 2000n;
        tx = await prediction.connect(otherAccount).bet(index, bet2Option, { value: bet2Value });
        await tx.wait();

        totalBet = await prediction.getPredictionTotalVotes(index);
        expect(totalBet).to.equal(bet1Value + bet2Value);

        let bets2 = await prediction.userBets(index, otherAccount.address);
        expect(bets2.length).to.equal(options.length);
        expect(bets2[bet2Option]).to.equal(bet2Value);

        // reveal
        let outcome = bet1Option;
        await time.increaseTo(unlockTime + 1);
        tx = await prediction.revealPrediction(index, outcome);
        await tx.wait();

        let first = await prediction.getPrediction(index);

        // withdraw
        let ratioBase = await prediction.RATIO_BASE();
        let totalShare = (bet1Value + bet2Value) * (ratioBase - feeRatio) / ratioBase;
        let claimable = await prediction.userClaimableAmount(index, owner.address);
        let target = bet1Value * totalShare / first.optionVotes[outcome];
        expect(claimable).to.equal(target);

        await expect(prediction.claim(index))
          .to.emit(prediction, "UserClaim")
          .withArgs(0, owner.address, claimable);
      });

      it("should only return unfinished prediction", async function() {
        const { prediction, unlockTime } = await loadFixture(deployPredictionFixture);
        
        await time.increaseTo(unlockTime + 1);
        const list = await prediction.getUnfinishedPredictions();
        expect(list.length).to.equal(0);
      });
    });

});