import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const Prediction = buildModule("Prediction", (m) => {

  const prediction = m.contract("Prediction");

  return { prediction };
});

export default Prediction;
