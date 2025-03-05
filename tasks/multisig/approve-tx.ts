import { task } from "hardhat/config";
import { getMultisigAddress } from "./utils";
import { Addressable } from "ethers";

type Params = {
  txid: string;
  multisig?: Addressable;
};

task("multisig:approve-tx", "Approve a pending transaction")
  .addPositionalParam("txid", "The transaction ID to approve")
  .addOptionalParam(
    "multisig",
    "Address of the multisig contract. If not provided, uses the deployed multisig"
  )
  .setAction(async ({ txid, multisig }: Params, hre) => {
    const multisigAddress = multisig ?? getMultisigAddress(hre);
    const multisigContract = await hre.ethers.getContractAt(
      "MultisigCaller",
      multisigAddress
    );
    const [_, secondSigner] = await hre.ethers.getSigners();

    const tx = await multisigContract.connect(secondSigner).approveTransaction(txid);
    const receipt = await tx.wait();

    console.log(`Transaction approved! Hash: ${receipt!.hash}`);
  });
