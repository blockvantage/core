import { expect } from "chai";
import { ethers } from "hardhat";
import {
  DummyContract,
  IERC20,
  Multicall3,
  MultisigAttacker,
  MultisigCaller,
  MockERC20,
  Address__factory,
} from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { Address } from "../lib/types";
import { AddressLike } from "ethers";
import { Multicaller, to } from "../lib/Multicaller";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("MultisigCaller", function () {
  let multisigCaller: MultisigCaller;
  let deployer: SignerWithAddress;
  let approver1: SignerWithAddress;
  let approver2: SignerWithAddress;
  let approver3: SignerWithAddress;
  let nonApprover: SignerWithAddress;

  const APPROVER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("APPROVER_ROLE"));
  const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));
  const REQUIRED_APPROVALS = 2;
  const MAX_APPROVERS = 10;
  const MIN_APPROVERS = 2;
  let addApproverTx: (approver: Address) => [AddressLike, number, string];
  let removeApproverTx: (approver: Address) => [AddressLike, number, string];

  async function fundMultisig(amount: bigint) {
    await deployer.sendTransaction({
      to: await multisigCaller.getAddress(),
      value: amount,
    });
  }

  async function deployMultisigCaller() {
    const MultisigCaller = await ethers.getContractFactory("MultisigCaller");
    multisigCaller = await MultisigCaller.deploy(
      [approver1.address, approver2.address, approver3.address],
      REQUIRED_APPROVALS
    );
    return multisigCaller;
  }

  beforeEach(async function () {
    [deployer, approver1, approver2, approver3, nonApprover] =
      await ethers.getSigners();

    multisigCaller = await loadFixture(deployMultisigCaller);

    addApproverTx = (approver: Address) =>
      [
        multisigCaller.getAddress(),
        0,
        multisigCaller.interface.encodeFunctionData("grantRole", [
          APPROVER_ROLE,
          approver,
        ]),
      ] as const;
    removeApproverTx = (approver: Address) =>
      [
        multisigCaller.getAddress(),
        0,
        multisigCaller.interface.encodeFunctionData("revokeRole", [
          APPROVER_ROLE,
          approver,
        ]),
      ] as const;
  });

  describe("Constructor", function () {
    it("should set up initial approvers correctly", async function () {
      expect(await multisigCaller.hasRole(APPROVER_ROLE, deployer.address)).to
        .be.false;
      expect(await multisigCaller.hasRole(APPROVER_ROLE, approver1.address)).to
        .be.true;
      expect(await multisigCaller.hasRole(APPROVER_ROLE, approver2.address)).to
        .be.true;
      expect(await multisigCaller.hasRole(APPROVER_ROLE, approver3.address)).to
        .be.true;
      expect(await multisigCaller.hasRole(APPROVER_ROLE, nonApprover.address))
        .to.be.false;
    });

    it("should set up contract as admin", async function () {
      expect(
        await multisigCaller.hasRole(
          ADMIN_ROLE,
          await multisigCaller.getAddress()
        )
      ).to.be.true;
    });

    it("should set required approvals correctly", async function () {
      expect(await multisigCaller.requiredApprovals()).to.equal(
        REQUIRED_APPROVALS
      );
    });

    it("should revert with invalid approver count", async function () {
      const MultisigCaller = await ethers.getContractFactory("MultisigCaller");
      const approversCount = 1;
      await expect(MultisigCaller.deploy([approver1.address], MIN_APPROVERS))
        .to.be.revertedWithCustomError(multisigCaller, "InvalidApproverCount")
        .withArgs(approversCount, MIN_APPROVERS);
    });

    it("should revert when required approvals exceed approvers count", async function () {
      const MultisigCaller = await ethers.getContractFactory("MultisigCaller");
      const approvers = [approver1.address, approver2.address];
      const tooManyApprovals = MAX_APPROVERS + 1;
      await expect(MultisigCaller.deploy(approvers, tooManyApprovals))
        .to.be.revertedWithCustomError(
          MultisigCaller,
          "RequiredApprovalsExceedApprovers"
        )
        .withArgs(tooManyApprovals, approvers.length);
    });

    it("should revert when required approvals is below minimum", async function () {
      const MultisigCaller = await ethers.getContractFactory("MultisigCaller");
      const approvers = [
        approver1.address,
        approver2.address,
        approver3.address,
      ];
      const tooFewApprovals = MIN_APPROVERS - 1;
      await expect(MultisigCaller.deploy(approvers, tooFewApprovals))
        .to.be.revertedWithCustomError(
          MultisigCaller,
          "RequiredApprovalsTooLow"
        )
        .withArgs(tooFewApprovals, MIN_APPROVERS);
    });

    it("should revert when approver address is zero", async function () {
      const MultisigCaller = await ethers.getContractFactory("MultisigCaller");
      const approvers = [
        approver1.address,
        ethers.ZeroAddress,
        approver3.address,
      ];
      await expect(
        MultisigCaller.deploy(approvers, REQUIRED_APPROVALS)
      ).to.be.revertedWithCustomError(MultisigCaller, "ZeroAddress");
    });
  });

  describe("Transaction Submission and Approval", function () {
    const value = ethers.parseEther("1.0");
    const data = "0x";
    let targetContract: string;

    beforeEach(async function () {
      const DummyContract = await ethers.getContractFactory("DummyContract");
      const dummyContract = await DummyContract.deploy();
      targetContract = await dummyContract.getAddress();
    });

    it("should allow approver to submit transaction", async function () {
      await expect(
        multisigCaller
          .connect(approver1)
          .submitTransaction(targetContract, value, data)
      )
        .to.emit(multisigCaller, "TransactionSubmitted")
        .withArgs(0, targetContract, value, data);
    });

    it("should not allow non-approver to submit transaction", async function () {
      await expect(
        multisigCaller
          .connect(nonApprover)
          .submitTransaction(targetContract, value, data)
      )
        .to.be.revertedWithCustomError(
          multisigCaller,
          "AccessControlUnauthorizedAccount"
        )
        .withArgs(nonApprover.address, APPROVER_ROLE);
    });

    it("should auto-approve on submission", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(targetContract, value, data);
      const tx = await multisigCaller.transactions(0);
      expect(tx.approvalCount).to.equal(1);
    });

    it("should allow multiple approvals and execute", async function () {
      await fundMultisig(ethers.parseEther("2.0"));

      await multisigCaller
        .connect(approver1)
        .submitTransaction(targetContract, value, data);
      const txId = 0;
      await expect(multisigCaller.connect(approver2).approveTransaction(txId))
        .to.emit(multisigCaller, "TransactionExecuted")
        .withArgs(txId);

      const tx = await multisigCaller.transactions(txId);
      expect(tx.executed).to.be.true;
    });

    it("should not allow double approval", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(targetContract, value, data);
      const txId = 0;
      await expect(multisigCaller.connect(approver1).approveTransaction(txId))
        .to.be.revertedWithCustomError(
          multisigCaller,
          "TransactionAlreadyApproved"
        )
        .withArgs(txId, approver1.address);
    });

    it("should not allow approval of non-existent transaction", async function () {
      const txId = 999;
      await expect(multisigCaller.connect(approver1).approveTransaction(txId))
        .to.be.revertedWithCustomError(multisigCaller, "InvalidTransactionId")
        .withArgs(txId);
    });

    it("should not allow approval of executed transaction", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(targetContract, 0, data);
      const txId = 0;
      await multisigCaller.connect(approver2).approveTransaction(txId);
      await expect(multisigCaller.connect(approver3).approveTransaction(txId))
        .to.be.revertedWithCustomError(
          multisigCaller,
          "TransactionAlreadyExecuted"
        )
        .withArgs(txId);
    });

    it("should not allow non-approver to approve transaction", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(targetContract, value, data);
      await expect(multisigCaller.connect(nonApprover).approveTransaction(0))
        .to.be.revertedWithCustomError(
          multisigCaller,
          "AccessControlUnauthorizedAccount"
        )
        .withArgs(nonApprover.address, APPROVER_ROLE);
    });
  });

  describe("Approver Management", function () {
    it("should allow adding new approver", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...addApproverTx(nonApprover.address));
      await multisigCaller.connect(approver2).approveTransaction(0);

      expect(await multisigCaller.hasRole(APPROVER_ROLE, nonApprover.address))
        .to.be.true;
    });

    it("should not exceed max approvers", async function () {
      for (let i = 0; i < 7; i++) {
        const newApprover = ethers.Wallet.createRandom();
        await multisigCaller
          .connect(approver1)
          .submitTransaction(...addApproverTx(newApprover.address));
        await multisigCaller.connect(approver2).approveTransaction(i);
      }

      const lastApprover = ethers.Wallet.createRandom();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...addApproverTx(lastApprover.address));
      await expect(multisigCaller.connect(approver2).approveTransaction(7))
        .to.be.revertedWithCustomError(multisigCaller, "MaxApproversReached")
        .withArgs(MAX_APPROVERS);
    });

    it("should not allow removing approver if it would make approvals impossible", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...removeApproverTx(approver2.address));
      await multisigCaller.connect(approver2).approveTransaction(0);
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...removeApproverTx(approver3.address));

      const currentApprovers = 2;
      await expect(multisigCaller.connect(approver3).approveTransaction(1))
        .to.be.revertedWithCustomError(multisigCaller, "InsufficientApprovers")
        .withArgs(REQUIRED_APPROVALS, currentApprovers);
    });

    it("should not allow non-admin to add approver", async function () {
      const newApprover = ethers.Wallet.createRandom();
      await expect(
        multisigCaller
          .connect(approver1)
          .grantRole(APPROVER_ROLE, newApprover.address)
      )
        .to.be.revertedWithCustomError(
          multisigCaller,
          "AccessControlUnauthorizedAccount"
        )
        .withArgs(approver1.address, DEFAULT_ADMIN_ROLE);
    });

    it("should not allow non-admin to remove approver", async function () {
      await expect(
        multisigCaller
          .connect(approver1)
          .revokeRole(APPROVER_ROLE, approver2.address)
      )
        .to.be.revertedWithCustomError(
          multisigCaller,
          "AccessControlUnauthorizedAccount"
        )
        .withArgs(approver1.address, DEFAULT_ADMIN_ROLE);
    });

    it("should revert when granting the approver role if it would exceed max approvers", async function () {
      for (let i = 0; i < 7; i++) {
        const newApprover = ethers.Wallet.createRandom();
        await multisigCaller
          .connect(approver1)
          .submitTransaction(...addApproverTx(newApprover.address));
        await multisigCaller.connect(approver2).approveTransaction(i);
      }

      const lastApprover = ethers.Wallet.createRandom();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...addApproverTx(lastApprover.address));
      await expect(multisigCaller.connect(approver2).approveTransaction(7))
        .to.be.revertedWithCustomError(multisigCaller, "MaxApproversReached")
        .withArgs(MAX_APPROVERS);
    });
  });

  describe("getApproversCount", function () {
    it("should return initial approvers count", async function () {
      expect(await multisigCaller.getRoleMemberCount(APPROVER_ROLE)).to.equal(
        3
      ); // approver1, approver2, approver3
    });

    it("should return updated count after adding approver", async function () {
      const newApprover = ethers.Wallet.createRandom();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...addApproverTx(newApprover.address));
      await multisigCaller.connect(approver2).approveTransaction(0);

      expect(await multisigCaller.getRoleMemberCount(APPROVER_ROLE)).to.equal(
        4
      );
    });

    it("should return updated count after removing approver", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(...removeApproverTx(approver2.address));
      await multisigCaller.connect(approver2).approveTransaction(0);

      expect(await multisigCaller.getRoleMemberCount(APPROVER_ROLE)).to.equal(
        2
      );
    });
  });

  describe("Required Approvals Management", function () {
    it("should allow changing required approvals", async function () {
      const contractAddress = await multisigCaller.getAddress();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(
          contractAddress,
          0,
          multisigCaller.interface.encodeFunctionData("setRequiredApprovals", [
            3,
          ])
        );
      await multisigCaller.connect(approver2).approveTransaction(0);

      expect(await multisigCaller.requiredApprovals()).to.equal(3);
    });

    it("should not allow required approvals below minimum", async function () {
      const contractAddress = await multisigCaller.getAddress();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(
          contractAddress,
          0,
          multisigCaller.interface.encodeFunctionData("setRequiredApprovals", [
            1,
          ])
        );
      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.be.revertedWithCustomError(
        multisigCaller,
        "RequiredApprovalsTooLow"
      );
    });

    it("should not allow required approvals above approver count", async function () {
      const contractAddress = await multisigCaller.getAddress();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(
          contractAddress,
          0,
          multisigCaller.interface.encodeFunctionData("setRequiredApprovals", [
            4,
          ])
        );
      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.be.revertedWithCustomError(
        multisigCaller,
        "RequiredApprovalsExceedApprovers"
      );
    });

    it("should now allow approvers to change required approvals", async function () {
      for (const approver of [approver1, approver2, approver3])
        await expect(multisigCaller.connect(approver).setRequiredApprovals(3))
          .to.be.revertedWithCustomError(
            multisigCaller,
            "AccessControlUnauthorizedAccount"
          )
          .withArgs(approver.address, ADMIN_ROLE);
    });
  });

  describe("Reentrancy Protection", function () {
    let attacker: MultisigAttacker;
    beforeEach(async function () {
      const AttackerContract = await ethers.getContractFactory(
        "MultisigAttacker"
      );
      attacker = await AttackerContract.deploy(
        await multisigCaller.getAddress()
      );

      await multisigCaller
        .connect(approver1)
        .submitTransaction(...addApproverTx(await attacker.getAddress()));
      await multisigCaller.connect(approver2).approveTransaction(0);
    });

    it("should prevent reentrancy in submitTransaction", async function () {
      await expect(attacker.attack())
        .to.be.revertedWithCustomError(
          multisigCaller,
          "TransactionAlreadyApproved"
        )
        .withArgs(1, await attacker.getAddress());
    });

    it("should prevent reentrancy in approveTransaction", async function () {
      await multisigCaller
        .connect(approver1)
        .submitTransaction(await attacker.getAddress(), 0, "0x");

      await expect(
        multisigCaller.connect(approver2).approveTransaction(1)
      ).to.be.revertedWithCustomError(
        multisigCaller,
        "ReentrancyGuardReentrantCall"
      );
    });
  });

  describe("Interaction with Ownable contracts", function () {
    let ownableTest: any;

    beforeEach(async function () {
      const OwnableTest = await ethers.getContractFactory("OwnableTest");
      ownableTest = await OwnableTest.deploy();

      await ownableTest.transferOwnership(await multisigCaller.getAddress());
    });

    it("should be able to transfer ownership through multisig", async function () {
      const contractAddress = await ownableTest.getAddress();
      const transferOwnershipData = ownableTest.interface.encodeFunctionData(
        "transferOwnership",
        [nonApprover.address]
      );
      await multisigCaller
        .connect(approver1)
        .submitTransaction(contractAddress, 0, transferOwnershipData);
      await multisigCaller.connect(approver2).approveTransaction(0);

      expect(await ownableTest.owner()).to.equal(nonApprover.address);

      const restrictedData =
        ownableTest.interface.encodeFunctionData("restrictedFunction");
      await expect(
        multisigCaller
          .connect(approver1)
          .submitTransaction(contractAddress, 0, restrictedData)
      ).not.to.be.reverted;

      await expect(multisigCaller.connect(approver2).approveTransaction(1))
        .to.be.revertedWithCustomError(
          ownableTest,
          "OwnableUnauthorizedAccount"
        )
        .withArgs(await multisigCaller.getAddress());
    });
  });

  describe("ETH Transfers", function () {
    const ETH_AMOUNT = ethers.parseEther("1.0");
    let recipient: SignerWithAddress;

    beforeEach(async function () {
      [recipient] = await ethers.getSigners();
    });

    it("should transfer ETH after required approvals", async function () {
      const recipientAddress = await recipient.getAddress();
      const multisigAddress = await multisigCaller.getAddress();

      await fundMultisig(ETH_AMOUNT);

      await multisigCaller
        .connect(approver1)
        .submitTransaction(recipientAddress, ETH_AMOUNT, "0x");

      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.changeEtherBalances(
        [multisigAddress, recipientAddress],
        [-ETH_AMOUNT, ETH_AMOUNT]
      );
    });

    it("should accept ETH during submission", async function () {
      const recipientAddress = await recipient.getAddress();

      await expect(
        multisigCaller
          .connect(approver1)
          .submitTransaction(recipientAddress, ETH_AMOUNT, "0x", {
            value: ETH_AMOUNT,
          })
      ).to.changeEtherBalances(
        [approver1, await multisigCaller.getAddress()],
        [-ETH_AMOUNT, ETH_AMOUNT]
      );
    });

    it("should accept ETH during submission and send it to receiver on approval", async function () {
      const recipientAddress = await recipient.getAddress();

      await multisigCaller
        .connect(approver1)
        .submitTransaction(recipientAddress, ETH_AMOUNT, "0x", {
          value: ETH_AMOUNT,
        });
      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.changeEtherBalances(
        [await multisigCaller.getAddress(), recipientAddress],
        [-ETH_AMOUNT, ETH_AMOUNT]
      );
    });

    it("should accept ETH during approval and send it to receiver", async function () {
      const recipientAddress = await recipient.getAddress();

      await multisigCaller
        .connect(approver1)
        .submitTransaction(recipientAddress, ETH_AMOUNT, "0x");

      await expect(
        multisigCaller.connect(approver2).approveTransaction(0, {
          value: ETH_AMOUNT,
        })
      ).to.changeEtherBalances(
        [approver2, recipientAddress],
        [-ETH_AMOUNT, ETH_AMOUNT]
      );
    });

    it("should fail when contract has insufficient ETH", async function () {
      const recipientAddress = await recipient.getAddress();

      await multisigCaller
        .connect(approver1)
        .submitTransaction(recipientAddress, ETH_AMOUNT, "0x");

      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.be.revertedWithCustomError(multisigCaller, "FailedCall");
    });

    it("should fail when ETH sent with approval is less than required", async function () {
      const recipientAddress = await recipient.getAddress();
      await multisigCaller
        .connect(approver1)
        .submitTransaction(recipientAddress, ETH_AMOUNT, "0x");

      await expect(
        multisigCaller.connect(approver2).approveTransaction(0, {
          value: ETH_AMOUNT / 2n,
        })
      ).to.be.revertedWithCustomError(multisigCaller, "FailedCall");
    });
  });

  describe("ERC20 Token Transfers", function () {
    let mockToken: IERC20;
    let recipient: SignerWithAddress;
    const TRANSFER_AMOUNT = ethers.parseUnits("1000", 18);

    beforeEach(async function () {
      const MockERC20 = await ethers.getContractFactory("MockERC20");
      mockToken = await MockERC20.deploy([await multisigCaller.getAddress()]);
      [recipient] = await ethers.getSigners();
    });

    function getTransferTx(to: Address, amount: bigint) {
      const iface = new ethers.Interface([
        "function transfer(address to, uint256 amount) returns (bool)",
      ]);
      return [
        mockToken.getAddress(),
        0n,
        iface.encodeFunctionData("transfer", [to, amount]),
      ] as const;
    }

    it("should transfer tokens after required approvals", async function () {
      const recipientAddress = await recipient.getAddress();
      const multisigAddress = await multisigCaller.getAddress();

      await multisigCaller
        .connect(approver1)
        .submitTransaction(...getTransferTx(recipientAddress, TRANSFER_AMOUNT));

      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.changeTokenBalances(
        mockToken,
        [multisigAddress, recipientAddress],
        [-TRANSFER_AMOUNT, TRANSFER_AMOUNT]
      );
    });

    it("should not transfer tokens before required approvals", async function () {
      const recipientAddress = await recipient.getAddress();
      const multisigAddress = await multisigCaller.getAddress();

      await expect(
        multisigCaller
          .connect(approver1)
          .submitTransaction(
            ...getTransferTx(recipientAddress, TRANSFER_AMOUNT)
          )
      ).to.changeTokenBalances(
        mockToken,
        [multisigAddress, recipientAddress],
        [0n, 0n]
      );
    });

    it("should fail if trying to transfer more than balance", async function () {
      const recipientAddress = await recipient.getAddress();
      const balance = await mockToken.balanceOf(
        await multisigCaller.getAddress()
      );
      const tooMuch = balance + 1n;

      await multisigCaller
        .connect(approver1)
        .submitTransaction(...getTransferTx(recipientAddress, tooMuch));
      await expect(multisigCaller.connect(approver2).approveTransaction(0))
        .to.be.revertedWithCustomError(mockToken, "ERC20InsufficientBalance")
        .withArgs(await multisigCaller.getAddress(), balance, tooMuch);
    });
  });

  describe("multicall", function () {
    let mockToken: IERC20;
    let dummyContract: DummyContract;

    beforeEach(async function () {
      const MockERC20 = await ethers.getContractFactory("MockERC20");
      mockToken = await MockERC20.deploy([await multisigCaller.getAddress()]);
      const DummyContract = await ethers.getContractFactory("DummyContract");
      dummyContract = await DummyContract.deploy();
    });

    it("should allow other contract to spend its funds in a single transaction", async function () {
      const encodedCalls = await Multicaller.mapCallsToContractCalls([
        to(mockToken, "approve", [await dummyContract.getAddress(), 100n]),
        to(dummyContract, "callTransferFrom", [
          await mockToken.getAddress(),
          await multisigCaller.getAddress(),
          await dummyContract.getAddress(),
          100n,
        ]),
      ]);
      const data = multisigCaller.interface.encodeFunctionData("aggregate3", [
        encodedCalls,
      ]);
      await multisigCaller
        .connect(approver1)
        .submitTransaction(multisigCaller.getAddress(), 0n, data);
      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.changeTokenBalances(
        mockToken,
        [await multisigCaller.getAddress(), await dummyContract.getAddress()],
        [-100n, 100n]
      );
    });

    it("should handle failed calls when allowFailure is true", async function () {
      const allowedWrongCall = {
        target: ethers.ZeroAddress,
        allowFailure: true,
        callData: "0x1234",
        value: 0,
      };
      const amount = 2;
      const calls = [
        allowedWrongCall,
        {
          target: await dummyContract.getAddress(),
          allowFailure: false,
          callData: "0x",
          value: amount,
        },
      ] as Multicall3.Call3ValueStruct[];

      await multisigCaller
        .connect(approver1)
        .submitTransaction(
          multisigCaller.getAddress(),
          amount,
          multisigCaller.interface.encodeFunctionData("aggregate3Value", [
            calls,
          ])
        );

      await expect(
        multisigCaller
          .connect(approver2)
          .approveTransaction(0, { value: amount })
      ).to.changeEtherBalance(await dummyContract.getAddress(), amount);
    });

    it("should revert entire transaction if a call fails and allowFailure is false", async function () {
      const disallowedWrongCall = {
        target: ethers.ZeroAddress,
        allowFailure: false,
        callData: "0x1234",
      };
      const calls = [
        disallowedWrongCall,
        {
          target: await dummyContract.getAddress(),
          allowFailure: true,
          callData: "0x",
          value: 2n,
        },
      ] as Multicall3.Call3Struct[];

      await multisigCaller
        .connect(approver1)
        .submitTransaction(
          multisigCaller.getAddress(),
          0n,
          multisigCaller.interface.encodeFunctionData("aggregate3", [calls])
        );

      await expect(
        multisigCaller.connect(approver2).approveTransaction(0)
      ).to.changeEtherBalance(await multisigCaller.getAddress(), 0n);
    });

    it("should handle value transfers correctly", async function () {
      const transferAmount = ethers.parseEther("1.0");
      const calls = [
        {
          target: await dummyContract.getAddress(),
          allowFailure: false,
          callData: "0x",
          value: transferAmount,
        },
      ];

      await multisigCaller
        .connect(approver1)
        .submitTransaction(
          multisigCaller.getAddress(),
          transferAmount,
          multisigCaller.interface.encodeFunctionData("aggregate3Value", [
            calls,
          ])
        );

      await expect(
        multisigCaller
          .connect(approver2)
          .approveTransaction(0, { value: transferAmount })
      ).to.changeEtherBalances(
        [await approver2.getAddress(), await dummyContract.getAddress()],
        [-transferAmount, transferAmount]
      );
    });

    it("should prevent non-admin from calling aggregate3 directly", async function () {
      const calls = [
        {
          target: await dummyContract.getAddress(),
          allowFailure: false,
          callData: "0x",
        },
      ];
      await expect(multisigCaller.connect(approver1).aggregate3(calls))
        .to.be.revertedWithCustomError(
          multisigCaller,
          "AccessControlUnauthorizedAccount"
        )
        .withArgs(approver1.address, ADMIN_ROLE);
    });
  });
});
