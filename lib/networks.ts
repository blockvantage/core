import { NetworksUserConfig } from "hardhat/types";

export function baseSepoliaWithPks(
  ...privateKeys: string[]
): NetworksUserConfig {
  return {
    baseSepolia: {
      ...baseSepolia,
      accounts: privateKeys,
    },
  };
}

export const baseSepolia = {
  chainId: 84532,
  url: "https://sepolia.base.org",
};
