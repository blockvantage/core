import { task } from "hardhat/config";
import { getMultisigAddress } from "./utils";
import { Addressable, Contract, Interface } from "ethers";
import { MultisigCaller } from "../../typechain-types";
import { findTransactionId } from "../utils";

type Params = { addresses: Addressable[] };

const OWNABLE_ABI = [
  "function owner() view returns (address)",
  "function transferOwnership(address newOwner) external",
] as const;

task(
  "multisig:submit-transfer-ownership-batch",
  "Submit a batch of transfer ownership transactions"
)
  .addVariadicPositionalParam(
    "addresses",
    "List of contract addresses to transfer ownership"
  )
  .setAction(async ({ addresses }: Params, hre) => {
    if (addresses.length === 0) {
      throw new Error("No addresses provided");
    }

    // Get the current owner from the first contract
    const ownableInterface = new Interface(OWNABLE_ABI);
    const firstContract = new Contract(
      addresses[0],
      ownableInterface,
      hre.ethers.provider
    );
    const oldMultisig = await firstContract.owner();
    console.log(`Current owner (from ${addresses[0]}): ${oldMultisig}`);

    const oldMultisigContract = await hre.ethers.getContractAt(
      "MultisigCaller",
      oldMultisig
    );

    const newMultisig = getMultisigAddress(hre);
    const calls: MultisigCaller.Call3Struct[] = addresses.map((address) => ({
      target: address,
      allowFailure: false,
      callData: ownableInterface.encodeFunctionData("transferOwnership", [
        newMultisig,
      ]),
    }));

    const tx = await oldMultisigContract.submitTransaction(
      oldMultisig,
      0,
      oldMultisigContract.interface.encodeFunctionData("aggregate3", [calls])
    );

    const receipt = await tx.wait();
    console.log(`Transaction submitted! Hash: ${receipt!.hash}`);

    const txId = findTransactionId(receipt!, oldMultisigContract);
    if (txId) {
      console.log(`Transaction ID: ${txId}`);
    }
  });
