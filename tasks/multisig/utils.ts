import { HardhatRuntimeEnvironment } from "hardhat/types";
import { baseSepolia } from "../../lib/networks";
import baseSepoliaDeployments from "../../ignition/deployments/chain-84532/deployed_addresses.json";

const multisigAddress: { [chainId: number]: string } = {
  [baseSepolia.chainId]:
    baseSepoliaDeployments["MultisigCaller#MultisigCaller"],
};

export const getMultisigAddress = (hre: HardhatRuntimeEnvironment) => {
  const chainId = hre.network.config.chainId;
  if (!chainId) throw new Error("Chain ID not found");

  const address = multisigAddress[chainId];
  if (!address)
    throw new Error(`MultisigCaller not deployed on chain ${chainId}`);

  return address;
};
