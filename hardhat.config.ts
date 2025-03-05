import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition";
import "./tasks";
import { baseSepoliaWithPks } from "./lib/networks";

const ADMIN_PK = vars.get("TOKENFLEET_ADMIN_PRIVATE_KEY");
const ANOTHER_ADMIN_PK = vars.get("TOKENFLEET_ANOTHER_ADMIN_PRIVATE_KEY");

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    ...baseSepoliaWithPks(ADMIN_PK, ANOTHER_ADMIN_PK),
  },
};

export default config;
