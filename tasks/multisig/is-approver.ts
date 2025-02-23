import { task } from "hardhat/config";
import { getMultisigAddress } from "./utils";

task("multisig:is-approver", "Check if an address is an approver")
  .addPositionalParam("address", "The address to check")
  .setAction(async ({ address }, hre) => {
    const multisig = await hre.ethers.getContractAt(
      "MultisigCaller",
      getMultisigAddress(hre)
    );

    const APPROVER_ROLE = await multisig.APPROVER_ROLE();
    const hasRole = await multisig.hasRole(APPROVER_ROLE, address);
    
    if (hasRole) {
      console.log(`✅ Address ${address} is an approver`);
    } else {
      console.log(`❌ Address ${address} is not an approver`);
    }
  });
