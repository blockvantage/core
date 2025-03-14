// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/MultisigCaller.sol";
import "../src/mock/DummyContract.sol";
import "../src/mock/MultisigAttacker.sol";
import "../src/mock/OwnableTest.sol";
import "../src/mock/MockERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MultisigCallerTest is Test {
    MultisigCaller multisigCaller;
    DummyContract dummyContract;
    OwnableTest ownableTest;
    
    address deployer;
    address approver1;
    address approver2;
    address approver3;
    address nonApprover;
    
    bytes32 constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    uint256 constant REQUIRED_APPROVALS = 2;
    uint256 constant MAX_APPROVERS = 10;
    uint256 constant MIN_APPROVERS = 2;

    function setUp() public {
        // Setup addresses
        deployer = address(this);
        approver1 = makeAddr("approver1");
        approver2 = makeAddr("approver2");
        approver3 = makeAddr("approver3");
        nonApprover = makeAddr("nonApprover");

        // Deploy contracts
        address[] memory approvers = new address[](3);
        approvers[0] = approver1;
        approvers[1] = approver2;
        approvers[2] = approver3;
        
        multisigCaller = new MultisigCaller(approvers, REQUIRED_APPROVALS);
        dummyContract = new DummyContract();
        ownableTest = new OwnableTest();
    }

    function testConstructor_InitialApprovers() public {
        assertFalse(multisigCaller.hasRole(APPROVER_ROLE, deployer));
        assertTrue(multisigCaller.hasRole(APPROVER_ROLE, approver1));
        assertTrue(multisigCaller.hasRole(APPROVER_ROLE, approver2));
        assertTrue(multisigCaller.hasRole(APPROVER_ROLE, approver3));
        assertFalse(multisigCaller.hasRole(APPROVER_ROLE, nonApprover));
    }

    function testConstructor_ContractAdmin() public {
        assertTrue(multisigCaller.hasRole(DEFAULT_ADMIN_ROLE, address(multisigCaller)));
    }

    function testConstructor_RequiredApprovals() public {
        assertEq(multisigCaller.requiredApprovals(), REQUIRED_APPROVALS);
    }

    function testConstructor_RevertInvalidApproverCount() public {
        address[] memory approvers = new address[](1);
        approvers[0] = approver1;
        
        vm.expectRevert(abi.encodeWithSignature("InvalidApproverCount(uint256,uint256)", 1, MIN_APPROVERS));
        new MultisigCaller(approvers, MIN_APPROVERS);
    }

    function testConstructor_RevertTooManyApprovals() public {
        address[] memory approvers = new address[](2);
        approvers[0] = approver1;
        approvers[1] = approver2;
        
        vm.expectRevert(abi.encodeWithSignature("RequiredApprovalsExceedApprovers(uint256,uint256)", MAX_APPROVERS + 1, 2));
        new MultisigCaller(approvers, MAX_APPROVERS + 1);
    }

    function testConstructor_RevertTooFewApprovals() public {
        address[] memory approvers = new address[](3);
        approvers[0] = approver1;
        approvers[1] = approver2;
        approvers[2] = approver3;
        
        vm.expectRevert(abi.encodeWithSignature("RequiredApprovalsTooLow(uint256,uint256)", MIN_APPROVERS - 1, MIN_APPROVERS));
        new MultisigCaller(approvers, MIN_APPROVERS - 1);
    }

    function testConstructor_RevertZeroAddress() public {
        address[] memory approvers = new address[](3);
        approvers[0] = approver1;
        approvers[1] = address(0);
        approvers[2] = approver3;
        
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        new MultisigCaller(approvers, REQUIRED_APPROVALS);
    }

    function testSubmitTransaction() public {
        uint256 value = 1 ether;
        bytes memory data = "";
        
        vm.prank(approver1);
        vm.expectEmit(true, true, true, true);
        emit MultisigCaller.TransactionSubmitted(0, address(dummyContract), value, data);
        multisigCaller.submitTransaction(address(dummyContract), value, data);
    }

    function testSubmitTransaction_RevertNonApprover() public {
        vm.prank(nonApprover);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", nonApprover, APPROVER_ROLE));
        multisigCaller.submitTransaction(address(dummyContract), 1 ether, "");
    }

    function testSubmitTransaction_AutoApprove() public {
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(dummyContract), 1 ether, "");
        
        (,,,, uint256 approvalCount) = multisigCaller.transactions(0);
        assertEq(approvalCount, 1);
    }

    function testMultipleApprovalsAndExecute() public {
        // Fund the multisig
        vm.deal(address(multisigCaller), 2 ether);
        
        // Submit transaction
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(dummyContract), 1 ether, "");
        
        // Second approval
        vm.expectEmit(true, true, true, true);
        emit MultisigCaller.TransactionExecuted(0);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        // Verify execution
        (,,, bool executed, uint256 approvalCount) = multisigCaller.transactions(0);
        assertEq(approvalCount, 2);
        assertTrue(executed);
    }

    function testShouldNotAllowDoubleApproval() public {
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(dummyContract), 1 ether, "");
        
        vm.prank(approver1);
        vm.expectRevert(abi.encodeWithSignature("TransactionAlreadyApproved(uint256,address)", 0, approver1));
        multisigCaller.approveTransaction(0);
    }

    function testShouldNotAllowApprovalOfNonExistentTransaction() public {
        vm.prank(approver1);
        vm.expectRevert(abi.encodeWithSignature("InvalidTransactionId(uint256)", 999));
        multisigCaller.approveTransaction(999);
    }

    function testShouldNotAllowApprovalOfExecutedTransaction() public {
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(dummyContract), 0 ether, "");
        
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        vm.prank(approver3);
        vm.expectRevert(abi.encodeWithSignature("TransactionAlreadyExecuted(uint256)", 0));
        multisigCaller.approveTransaction(0);
    }

    function testApproverManagement_ShouldAllowAddingNewApprover() public {
        // Prepare transaction to add new approver
        bytes memory addApproverData = abi.encodeWithSelector(
            MultisigCaller.grantRole.selector,
            APPROVER_ROLE,
            nonApprover
        );
        // Submit and approve transaction
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, addApproverData);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        assertTrue(multisigCaller.hasRole(APPROVER_ROLE, nonApprover));
    }

    function testApproverManagement_ShouldNotExceedMaxApprovers() public {
        // Add 7 new approvers
        for (uint256 i = 0; i < 7; i++) {
            address newApprover = makeAddr(string.concat("newApprover", vm.toString(i)));
            
            bytes memory addApproverData = abi.encodeWithSelector(
                MultisigCaller.grantRole.selector,
                APPROVER_ROLE,
                newApprover
            );
            
            vm.prank(approver1);
            multisigCaller.submitTransaction(address(multisigCaller), 0, addApproverData);
            
            vm.prank(approver2);
            multisigCaller.approveTransaction(i);
        }

        // Try to add one more approver
        address lastApprover = makeAddr("lastApprover");
        bytes memory lastApproverData = abi.encodeWithSelector(
            MultisigCaller.grantRole.selector,
            APPROVER_ROLE,
            lastApprover
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, lastApproverData);
        
        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("MaxApproversReached(uint256)", MAX_APPROVERS));
        multisigCaller.approveTransaction(7);
    }

    function testApproverManagement_ShouldNotAllowRemovingIfInsufficientApprovers() public {
        // Try to remove approver2
        bytes memory removeApproverData = abi.encodeWithSelector(
            MultisigCaller.revokeRole.selector,
            APPROVER_ROLE,
            approver2
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, removeApproverData);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        // Try to remove approver3
        bytes memory removeAnotherApproverData = abi.encodeWithSelector(
            MultisigCaller.revokeRole.selector,
            APPROVER_ROLE,
            approver3
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, removeAnotherApproverData);

        vm.prank(approver3);
        vm.expectRevert(abi.encodeWithSignature("InsufficientApprovers(uint256,uint256)", REQUIRED_APPROVALS, 2));
        multisigCaller.approveTransaction(1);
    }

    function testApproverManagement_ShouldNotAllowNonAdminToAddApprover() public {
        address newApprover = makeAddr("newApprover");
        
        vm.prank(approver1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                approver1,
                DEFAULT_ADMIN_ROLE
            )
        );
        multisigCaller.grantRole(APPROVER_ROLE, newApprover);
    }

    function testApproverManagement_ShouldNotAllowNonAdminToRemoveApprover() public {
        vm.prank(approver1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                approver1,
                DEFAULT_ADMIN_ROLE
            )
        );
        multisigCaller.revokeRole(APPROVER_ROLE, approver2);
    }

    function testRequiredApprovalsManagement_ShouldAllowChangingRequiredApprovals() public {
        bytes memory changeApprovalsData = abi.encodeWithSelector(
            MultisigCaller.setRequiredApprovals.selector,
            3
        );
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, changeApprovalsData);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        assertEq(multisigCaller.requiredApprovals(), 3);
    }

    function testRequiredApprovalsManagement_ShouldNotAllowBelowMinimum() public {
        bytes memory changeApprovalsData = abi.encodeWithSelector(
            MultisigCaller.setRequiredApprovals.selector,
            1
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, changeApprovalsData);
        
        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("RequiredApprovalsTooLow(uint256,uint256)", 1, 2));
        multisigCaller.approveTransaction(0);
    }

    function testRequiredApprovalsManagement_ShouldNotAllowAboveApproverCount() public {
        bytes memory changeApprovalsData = abi.encodeWithSelector(
            MultisigCaller.setRequiredApprovals.selector,
            4
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, changeApprovalsData);
        
        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("RequiredApprovalsExceedApprovers(uint256,uint256)", 4, 3));
        multisigCaller.approveTransaction(0);
    }

    function testRequiredApprovalsManagement_ShouldNotAllowDirectChange() public {
        address[] memory approvers = new address[](3);
        approvers[0] = approver1;
        approvers[1] = approver2;
        approvers[2] = approver3;
        
        for (uint i = 0; i < approvers.length; i++) {
            vm.prank(approvers[i]);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AccessControlUnauthorizedAccount(address,bytes32)",
                    approvers[i],
                    DEFAULT_ADMIN_ROLE
                )
            );
            multisigCaller.setRequiredApprovals(3);
        }
    }

    function testEthTransfers_ShouldTransferETHAfterRequiredApprovals() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;
        
        // Fund the multisig
        vm.deal(address(multisigCaller), amount);
        
        // Submit transfer transaction
        vm.prank(approver1);
        multisigCaller.submitTransaction(recipient, amount, "");
        
        uint256 recipientBalance = recipient.balance;
        
        // Complete required approvals
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        // Verify transfer
        assertEq(recipient.balance, recipientBalance + amount);
        assertEq(address(multisigCaller).balance, 0);
    }

    function testEthTransfers_ShouldAcceptETHDuringSubmission() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;

        // Fund approver1
        vm.deal(approver1, amount);

        uint256 approverBalanceBefore = approver1.balance;
        uint256 multisigBalanceBefore = address(multisigCaller).balance;

        vm.prank(approver1);
        multisigCaller.submitTransaction{value: amount}(recipient, amount, "0x");

        assertEq(approver1.balance, approverBalanceBefore - amount, "Approver balance should decrease");
        assertEq(address(multisigCaller).balance, multisigBalanceBefore + amount, "Multisig balance should increase");
    }

    function testEthTransfers_ShouldAcceptETHInSubmissionAndSendToReceiverOnApproval() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;

        // Fund approver1
        vm.deal(approver1, amount);

        vm.prank(approver1);
        multisigCaller.submitTransaction{value: amount}(recipient, amount, "0x");

        uint256 multisigBalanceBefore = address(multisigCaller).balance;
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        assertEq(address(multisigCaller).balance, multisigBalanceBefore - amount, "Multisig balance should decrease");
        assertEq(recipient.balance, recipientBalanceBefore + amount, "Recipient balance should increase");
    }

    function testEthTransfers_ShouldAcceptETHDuringApprovalAndSendToReceiver() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;

        vm.prank(approver1);
        multisigCaller.submitTransaction(recipient, amount, "0x");

        // Fund approver2
        vm.deal(approver2, amount);

        uint256 approverBalanceBefore = approver2.balance;
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(approver2);
        multisigCaller.approveTransaction{value: amount}(0);

        assertEq(approver2.balance, approverBalanceBefore - amount, "Approver balance should decrease");
        assertEq(recipient.balance, recipientBalanceBefore + amount, "Recipient balance should increase");
    }

    function testEthTransfers_ShouldFailWithInsufficientContractBalance() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;

        vm.prank(approver1);
        multisigCaller.submitTransaction(recipient, amount, "0x");

        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("FailedCall()"));
        multisigCaller.approveTransaction(0);
    }

    function testEthTransfers_ShouldFailWhenApprovalETHLessThanRequired() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;

        vm.prank(approver1);
        multisigCaller.submitTransaction(recipient, amount, "0x");

        // Fund approver2 with half the required amount
        vm.deal(approver2, amount / 2);

        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("FailedCall()"));
        multisigCaller.approveTransaction{value: amount / 2}(0);
    }

    function testGetApproversCount_ShouldReturnInitialCount() public {
        assertEq(multisigCaller.getRoleMemberCount(APPROVER_ROLE), 3); 
    }

    function testGetApproversCount_ShouldUpdateAfterAddingApprover() public {
        address newApprover = makeAddr("newApprover");
        bytes memory addApproverData = abi.encodeWithSelector(
            MultisigCaller.grantRole.selector,
            APPROVER_ROLE,
            newApprover
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, addApproverData);
        
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        assertEq(multisigCaller.getRoleMemberCount(APPROVER_ROLE), 4);
    }

    function testGetApproversCount_ShouldUpdateAfterRemovingApprover() public {
        bytes memory removeApproverData = abi.encodeWithSelector(
            MultisigCaller.revokeRole.selector,
            APPROVER_ROLE,
            approver2
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, removeApproverData);
        
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        assertEq(multisigCaller.getRoleMemberCount(APPROVER_ROLE), 2);
    }

    function testFuzz_RequiredApprovals(uint256 newRequiredApprovals) public {
        // Skip valid values (2 and 3 for our setup)
        vm.assume(newRequiredApprovals < 2 || newRequiredApprovals > 3);
        
        bytes memory changeApprovalsData = abi.encodeWithSelector(
            MultisigCaller.setRequiredApprovals.selector,
            newRequiredApprovals
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, changeApprovalsData);
        
        vm.prank(approver2);
        
        if (newRequiredApprovals < 2) {
            vm.expectRevert(abi.encodeWithSignature(
                "RequiredApprovalsTooLow(uint256,uint256)",
                newRequiredApprovals,
                2
            ));
        } else {
            vm.expectRevert(abi.encodeWithSignature(
                "RequiredApprovalsExceedApprovers(uint256,uint256)",
                newRequiredApprovals,
                3
            ));
        }
        
        multisigCaller.approveTransaction(0);
    }

    function testFuzz_RequiredApprovalsValid(uint256 newRequiredApprovals) public {
        // Only test valid values
        vm.assume(newRequiredApprovals >= 2 && newRequiredApprovals <= 3);
        
        bytes memory changeApprovalsData = abi.encodeWithSelector(
            MultisigCaller.setRequiredApprovals.selector,
            newRequiredApprovals
        );
        
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, changeApprovalsData);
        
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        assertEq(multisigCaller.requiredApprovals(), newRequiredApprovals);
    }

    function testFuzz_EthTransfers(uint256 amount) public {
        // Bound amount to reasonable values and avoid zero
        amount = bound(amount, 1, 100 ether);
        
        address recipient = makeAddr("recipient");
        uint256 recipientBalance = recipient.balance;
        
        // Fund the contract
        vm.deal(address(multisigCaller), amount);
        
        // Submit transfer transaction
        vm.prank(approver1);
        multisigCaller.submitTransaction(recipient, amount, "");
        
        // Second approval
        vm.expectEmit(true, true, true, true);
        emit MultisigCaller.TransactionExecuted(0);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);
        
        // Verify transfer
        assertEq(recipient.balance, recipientBalance + amount);
        assertEq(address(multisigCaller).balance, 0);
    }

    function testFuzz_EthTransfers_ShouldRevertIfInsufficientBalance(uint256 amount) public {
        // Bound amount to reasonable values, avoid zero, and ensure it's more than contract balance
        amount = bound(amount, 1 ether + 1, 100 ether);
        
        address recipient = makeAddr("recipient");
        
        // Fund the contract with less than amount
        vm.deal(address(multisigCaller), 1 ether);
        
        // Submit transfer transaction
        vm.prank(approver1);
        multisigCaller.submitTransaction(recipient, amount, "");
        
        // Second approval should fail due to insufficient balance
        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("FailedCall()"));
        multisigCaller.approveTransaction(0);
        
        // Verify balances remain unchanged
        assertEq(address(multisigCaller).balance, 1 ether);
        assertEq(recipient.balance, 0);
    }

    function testReentrancy_ShouldPreventInSubmitTransaction() public {
        MultisigAttacker attacker = new MultisigAttacker(address(multisigCaller));
        
        // Add attacker as an approver
        bytes memory addApproverData = abi.encodeWithSelector(
            MultisigCaller.grantRole.selector,
            APPROVER_ROLE,
            address(attacker)
        );
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, addApproverData);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        // Now attempt the attack
        vm.expectRevert(abi.encodeWithSignature("TransactionAlreadyApproved(uint256,address)", 1, address(attacker)));
        attacker.attack();
    }

    function testReentrancy_ShouldPreventInApproveTransaction() public {
        // Submit a transaction that will trigger the reentrancy attempt
        bytes memory approveData = abi.encodeWithSelector(
            MultisigCaller.approveTransaction.selector,
            1
        );
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, approveData);

        // Try to approve, which should trigger the reentrancy guard
        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("ReentrancyGuardReentrantCall()"));
        multisigCaller.approveTransaction(0);
    }

    function testOwnable_ShouldTransferOwnershipThroughMultisig() public {
        // Deploy and setup OwnableTest
        ownableTest.transferOwnership(address(multisigCaller));

        // Transfer ownership to nonApprover through multisig
        bytes memory transferData = abi.encodeWithSelector(
            Ownable.transferOwnership.selector,
            nonApprover
        );
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(ownableTest), 0, transferData);
        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        // Verify ownership transfer
        assertEq(ownableTest.owner(), nonApprover);

        // Try to call restricted function - should fail since multisig is no longer owner
        bytes memory restrictedData = abi.encodeWithSelector(
            OwnableTest.restrictedFunction.selector
        );
        vm.prank(approver1);
        multisigCaller.submitTransaction(address(ownableTest), 0, restrictedData);

        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(multisigCaller)));
        multisigCaller.approveTransaction(1);
    }

    function testERC20_ShouldTransferTokensAfterRequiredApprovals() public {
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(multisigCaller);
        MockERC20 token = new MockERC20(beneficiaries);
        
        address recipient = makeAddr("recipient");
        uint256 amount = 1000 ether;

        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            recipient,
            amount
        );

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(token), 0, transferData);

        uint256 multisigBalanceBefore = token.balanceOf(address(multisigCaller));
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        assertEq(token.balanceOf(address(multisigCaller)), multisigBalanceBefore - amount, "Multisig balance should decrease");
        assertEq(token.balanceOf(recipient), recipientBalanceBefore + amount, "Recipient balance should increase");
    }

    function testERC20_ShouldNotTransferTokensBeforeRequiredApprovals() public {
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(multisigCaller);
        MockERC20 token = new MockERC20(beneficiaries);
        
        address recipient = makeAddr("recipient");
        uint256 amount = 1000 ether;

        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            recipient,
            amount
        );

        uint256 multisigBalanceBefore = token.balanceOf(address(multisigCaller));
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(token), 0, transferData);

        assertEq(token.balanceOf(address(multisigCaller)), multisigBalanceBefore, "Multisig balance should not change");
        assertEq(token.balanceOf(recipient), recipientBalanceBefore, "Recipient balance should not change");
    }

    function testERC20_ShouldFailIfTransferringMoreThanBalance() public {
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(multisigCaller);
        MockERC20 token = new MockERC20(beneficiaries);
        
        address recipient = makeAddr("recipient");
        uint256 balance = token.balanceOf(address(multisigCaller));
        uint256 tooMuch = balance + 1;

        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            recipient,
            tooMuch
        );

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(token), 0, transferData);

        vm.prank(approver2);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", address(multisigCaller), balance, tooMuch));
        multisigCaller.approveTransaction(0);
    }

    function testMulticall_ShouldAllowContractToSpendFundsInSingleTransaction() public {
        // Setup contracts
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(multisigCaller);
        MockERC20 token = new MockERC20(beneficiaries);
        DummyContract dummy = new DummyContract();

        // Prepare multicall data
        MultisigCaller.Call3[] memory calls = new MultisigCaller.Call3[](2);
        
        // First call: approve
        calls[0] = MultisigCaller.Call3({
            target: address(token),
            allowFailure: false,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(dummy), 100)
        });

        // Second call: transferFrom
        calls[1] = MultisigCaller.Call3({
            target: address(dummy),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                DummyContract.callTransferFrom.selector,
                address(token),
                address(multisigCaller),
                address(dummy),
                100
            )
        });

        bytes memory multicallData = abi.encodeWithSelector(
            MultisigCaller.aggregate3.selector,
            calls
        );

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, multicallData);

        uint256 multisigBalanceBefore = token.balanceOf(address(multisigCaller));
        uint256 dummyBalanceBefore = token.balanceOf(address(dummy));

        vm.prank(approver2);
        multisigCaller.approveTransaction(0);

        assertEq(token.balanceOf(address(multisigCaller)), multisigBalanceBefore - 100, "Multisig balance should decrease");
        assertEq(token.balanceOf(address(dummy)), dummyBalanceBefore + 100, "Dummy balance should increase");
    }

    function testMulticall_ShouldHandleFailedCallsWhenAllowFailureIsTrue() public {
        DummyContract dummy = new DummyContract();
        uint256 amount = 2;

        MultisigCaller.Call3Value[] memory calls = new MultisigCaller.Call3Value[](2);
        
        // First call: will fail but allowed
        calls[0] = MultisigCaller.Call3Value({
            target: address(dummy),
            allowFailure: true,
            value: 0,
            callData: hex"1234"
        });

        // Second call: send ETH
        calls[1] = MultisigCaller.Call3Value({
            target: address(dummy),
            allowFailure: false,
            value: amount,
            callData: ""
        });

        bytes memory multicallData = abi.encodeWithSelector(
            MultisigCaller.aggregate3Value.selector,
            calls
        );

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), amount, multicallData);

        uint256 dummyBalanceBefore = address(dummy).balance;

        vm.deal(approver2, amount);
        vm.prank(approver2);
        multisigCaller.approveTransaction{value: amount}(0);

        assertEq(address(dummy).balance, dummyBalanceBefore + amount, "Dummy balance should increase");
    }

    function testMulticall_ShouldRevertIfCallFailsAndAllowFailureIsFalse() public {
        DummyContract dummy = new DummyContract();

        MultisigCaller.Call3[] memory calls = new MultisigCaller.Call3[](2);
        
        // First call: will fail and not allowed
        calls[0] = MultisigCaller.Call3({
            target: address(dummy),
            allowFailure: false,
            callData: hex"1234"
        });

        // Second call: would succeed but won't execute
        calls[1] = MultisigCaller.Call3({
            target: address(dummy),
            allowFailure: true,
            callData: hex"1234"
        });

        bytes memory multicallData = abi.encodeWithSelector(
            MultisigCaller.aggregate3.selector,
            calls
        );

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), 0, multicallData);

        vm.prank(approver2);
        vm.expectRevert("Multicall3: call failed");
        multisigCaller.approveTransaction(0);
    }

    function testMulticall_ShouldHandleValueTransfersCorrectly() public {
        DummyContract dummy = new DummyContract();
        uint256 amount = 1 ether;

        MultisigCaller.Call3Value[] memory calls = new MultisigCaller.Call3Value[](1);
        calls[0] = MultisigCaller.Call3Value({
            target: address(dummy),
            allowFailure: false,
            value: amount,
            callData: ""
        });

        bytes memory multicallData = abi.encodeWithSelector(
            MultisigCaller.aggregate3Value.selector,
            calls
        );

        vm.prank(approver1);
        multisigCaller.submitTransaction(address(multisigCaller), amount, multicallData);

        vm.deal(approver2, amount);
        uint256 approverBalanceBefore = approver2.balance;
        uint256 dummyBalanceBefore = address(dummy).balance;

        vm.prank(approver2);
        multisigCaller.approveTransaction{value: amount}(0);

        assertEq(approver2.balance, approverBalanceBefore - amount, "Approver balance should decrease");
        assertEq(address(dummy).balance, dummyBalanceBefore + amount, "Dummy balance should increase");
    }

    function testMulticall_ShouldPreventNonAdminFromCallingAggregate3Directly() public {
        DummyContract dummy = new DummyContract();

        MultisigCaller.Call3[] memory calls = new MultisigCaller.Call3[](1);
        calls[0] = MultisigCaller.Call3({
            target: address(dummy),
            allowFailure: false,
            callData: ""
        });

        vm.prank(approver1);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            approver1,
            DEFAULT_ADMIN_ROLE
        ));
        multisigCaller.aggregate3(calls);
    }
}
