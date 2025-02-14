import { BaseContract } from "ethers";
import { Multicall3 } from "../typechain-types";

export class Multicaller {
  static async mapCallsToContractCalls(
    calls: Call[]
  ): Promise<Multicall3.Call3Struct[]> {
    return Promise.all(
      calls.map(async (call) => ({
        target: await call.contract.getAddress(),
        callData: call.contract.interface.encodeFunctionData(
          call.method,
          call.args
        ),
        allowFailure: call.allowFailure ?? false,
      }))
    );
  }
}

export type Call = {
  contract: BaseContract;
  method: string;
  args: any[];
  allowFailure?: boolean;
};

export function to<T extends BaseContract, M extends keyof T & string>(
  contract: T,
  method: M,
  args: T[M] extends { populateTransaction: (...args: infer A) => Promise<any> }
    ? A
    : never,
  allowFailure?: boolean
) {
  return {
    contract,
    method,
    args,
    allowFailure,
  } as Call;
}
