// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/Lock.sol";

contract LockTest is Test {
    Lock lock;
    uint256 unlockTime;
    uint256 constant ONE_YEAR_IN_SECS = 365 days;
    uint256 constant ONE_GWEI = 1_000_000_000;
    address owner;
    address otherAccount;

    receive() external payable {}

    function setUp() public {
        unlockTime = block.timestamp + ONE_YEAR_IN_SECS;
        owner = makeAddr("owner");
        otherAccount = makeAddr("other");

        // Fund the owner account for deployment
        vm.deal(owner, ONE_GWEI);

        // Deploy with value from owner account
        vm.prank(owner);
        lock = new Lock{value: ONE_GWEI}(unlockTime);
    }

    function testDeployment_ShouldSetRightUnlockTime() public {
        assertEq(lock.unlockTime(), unlockTime);
    }

    function testDeployment_ShouldSetRightOwner() public {
        assertEq(lock.owner(), owner);
    }

    function testDeployment_ShouldReceiveAndStoreFunds() public {
        assertEq(address(lock).balance, ONE_GWEI);
    }

    function testDeployment_ShouldFailIfUnlockTimeNotInFuture() public {
        uint256 currentTime = block.timestamp;
        vm.expectRevert("Unlock time should be in the future");
        new Lock{value: 1}(currentTime);
    }

    function testFuzz_ShouldFailIfUnlockTimeNotInFuture(uint256 unlockTime) public {
        vm.assume(unlockTime <= block.timestamp);
        vm.expectRevert("Unlock time should be in the future");
        new Lock{value: 1}(unlockTime);
    }

    function testFuzz_ShouldSucceedIfUnlockTimeInFuture(uint256 unlockTime) public {
        vm.assume(unlockTime > block.timestamp);
        vm.assume(unlockTime < type(uint256).max); // Prevent overflow

        vm.deal(address(this), ONE_GWEI);
        Lock newLock = new Lock{value: ONE_GWEI}(unlockTime);

        assertEq(newLock.unlockTime(), unlockTime);
        assertEq(address(newLock).balance, ONE_GWEI);
    }

    function testFuzz_ShouldHandleVariousDeploymentAmounts(uint256 amount) public {
        // Bound amount to reasonable values and avoid zero
        amount = bound(amount, 1, 100 ether);

        vm.deal(address(this), amount);
        Lock newLock = new Lock{value: amount}(block.timestamp + ONE_YEAR_IN_SECS);

        assertEq(address(newLock).balance, amount);
    }

    function testFuzz_ShouldTransferVariousAmounts(uint256 amount) public {
        // Bound amount to reasonable values and avoid zero
        amount = bound(amount, ONE_GWEI, 100 ether);

        // Setup
        vm.deal(address(this), amount);
        uint256 preBalance = address(this).balance;

        Lock newLock = new Lock{value: amount}(block.timestamp + 1);
        assertEq(address(newLock).balance, amount);
        assertEq(address(this).balance, preBalance - amount);

        // Warp to unlock time and withdraw as owner
        vm.warp(block.timestamp + 1);

        // Reset our balance to ensure accurate withdrawal tracking
        vm.deal(address(this), 0);

        newLock.withdraw();

        assertEq(address(this).balance, amount);
        assertEq(address(newLock).balance, 0);
    }

    function testWithdraw_ShouldRevertIfCalledTooSoon() public {
        vm.expectRevert("You can't withdraw yet");
        lock.withdraw();
    }

    function testWithdraw_ShouldRevertIfCalledFromAnotherAccount() public {
        vm.warp(unlockTime);

        // Try to withdraw from another account
        vm.prank(otherAccount);
        vm.expectRevert("You aren't the owner");
        lock.withdraw();
    }

    function testWithdraw_ShouldSucceedIfUnlockTimeArrivedAndOwnerCalls() public {
        vm.warp(unlockTime);

        // Ensure we're the owner for withdrawal
        vm.prank(owner);
        lock.withdraw();
    }

    function testWithdraw_ShouldEmitWithdrawalEvent() public {
        vm.warp(unlockTime);

        // Ensure we're the owner for withdrawal
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit Lock.Withdrawal(ONE_GWEI, block.timestamp);

        lock.withdraw();

        vm.stopPrank();
    }

    function testWithdraw_ShouldTransferFundsToOwner() public {
        vm.warp(unlockTime);

        // Ensure we're the owner for withdrawal
        vm.prank(owner);

        // Record balances before withdrawal
        uint256 preOwnerBalance = address(owner).balance;

        lock.withdraw();

        // Check final balances
        assertEq(address(owner).balance, preOwnerBalance + ONE_GWEI);
        assertEq(address(lock).balance, 0);
    }
}
