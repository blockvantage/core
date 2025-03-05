import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export interface MultisigCallerConfig {
  approvers: string[];
  requiredApprovals?: number;
}

export default buildModule("MultisigCaller", (m) => {
  const approvers = m.getParameter<string[]>("approvers");
  const requiredApprovals = m.getParameter<number>("requiredApprovals");

  const multisigCaller = m.contract("MultisigCaller", [
    approvers,
    requiredApprovals,
  ]);

  return { multisigCaller };
});
