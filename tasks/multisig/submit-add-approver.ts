import { task } from "hardhat/config";
import { findTransactionId } from "../utils";
import { getMultisigAddress } from "./utils";

task(
  "multisig:submit-add-approver",
  "Submit a transaction to add a new approver"
)
  .addPositionalParam("approver", "The address of the new approver to add")
  .setAction(async ({ approver }, hre) => {
    const multisig = await hre.ethers.getContractAt(
      "MultisigCaller",
      getMultisigAddress(hre)
    );
    const addApproverData = multisig.interface.encodeFunctionData(
      "addApprover",
      [approver]
    );

    const ZERO_VALUE = 0;
    const tx = await multisig.submitTransaction(
      getMultisigAddress(hre),
      ZERO_VALUE,
      addApproverData
    );

    const receipt = await tx.wait();
    console.log(`Transaction submitted! Hash: ${receipt!.hash}`);

    const txId = findTransactionId(receipt!, multisig);
    if (txId) {
      console.log(`Transaction ID: ${txId}`);
    }
  });
