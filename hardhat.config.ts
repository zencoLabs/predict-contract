import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    cfx: {
      url: "https://evm.confluxrpc.com",
      chainId: 1030,
      accounts: [process.env.PRIVATE_KEY as string],
    },
    cfxTest: {
      url: "https://evmtestnet.confluxrpc.com",
      chainId: 71,
      accounts: [process.env.PRIVATE_KEY as string],
    }
  }
};

export default config;
