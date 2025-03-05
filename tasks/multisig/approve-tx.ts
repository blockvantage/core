import { task } from "hardhat/config";
import { getMultisigAddress } from "./utils";

task("multisig:approve-tx", "Approve a pending transaction")
  .addPositionalParam("txid", "The transaction ID to approve")
  .setAction(async ({ txid }, hre) => {
    const multisig = await hre.ethers.getContractAt(
      "MultisigCaller",
      getMultisigAddress(hre)
    );
    const [_, secondSigner] = await hre.ethers.getSigners();

    const tx = await multisig.connect(secondSigner).approveTransaction(txid);
    const receipt = await tx.wait();

    console.log(`Transaction approved! Hash: ${receipt!.hash}`);
  });
