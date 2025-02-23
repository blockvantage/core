import { ContractTransactionReceipt, Log } from "ethers";
import { MultisigCaller } from "../typechain-types";

export const findTransactionId = (
  receipt: ContractTransactionReceipt,
  contract: MultisigCaller
): string | undefined => {
  const event = receipt.logs
    .map((log: Log) => {
      try {
        return contract.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((event) => event?.name === "TransactionSubmitted");

  return event?.args.txId.toString();
};
