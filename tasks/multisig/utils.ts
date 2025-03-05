import { HardhatRuntimeEnvironment } from "hardhat/types";
import { baseSepolia } from "../../lib/networks";

const multisigAddress: { [chainId: number]: string } = {
  [baseSepolia.chainId]: "0xE52566731f732A2eF1be7E3FD27833e7451b3b04",
};

export const getMultisigAddress = (hre: HardhatRuntimeEnvironment) => {
  const chainId = hre.network.config.chainId;
  if (!chainId) throw new Error("Chain ID not found");

  const address = multisigAddress[chainId];
  if (!address)
    throw new Error(`MultisigCaller not deployed on chain ${chainId}`);

  return address;
};
