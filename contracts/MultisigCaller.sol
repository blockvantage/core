// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

error InvalidApproverCount(uint256 count, uint256 minimum);
error RequiredApprovalsTooLow(uint256 required, uint256 minimum);
error RequiredApprovalsExceedApprovers(uint256 required, uint256 approvers);
error ZeroAddress();
error MaxApproversReached(uint256 max);
error InsufficientApprovers(uint256 required, uint256 approvers);
error InvalidTransactionId(uint256 txId);
error TransactionAlreadyExecuted(uint256 txId);
error TransactionAlreadyApproved(uint256 txId, address approver);

contract MultisigCaller is AccessControlEnumerable, ReentrancyGuard {
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant MIN_APPROVERS = 2;
    uint256 public constant MAX_APPROVERS = 10;
    
    uint256 public requiredApprovals;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approvals;

    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionApproved(uint256 indexed txId, address indexed approver);
    event TransactionExecuted(uint256 indexed txId);
    event ApproverAdded(address indexed account);
    event ApproverRemoved(address indexed account);
    event RequiredApprovalsChanged(uint256 oldRequired, uint256 newRequired);

    using Address for address;

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    constructor(address[] memory approvers, uint256 _requiredApprovals) {
        if (approvers.length < MIN_APPROVERS) revert InvalidApproverCount(approvers.length, MIN_APPROVERS);
        if (_requiredApprovals > approvers.length) revert RequiredApprovalsExceedApprovers(_requiredApprovals, approvers.length);
        if (_requiredApprovals < MIN_APPROVERS) revert RequiredApprovalsTooLow(_requiredApprovals, MIN_APPROVERS);

        requiredApprovals = _requiredApprovals;

        // Setup the contract itself as the admin
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
        _grantRole(ADMIN_ROLE, address(this));

        // Setup initial approvers
        for (uint256 i = 0; i < approvers.length; i++) {
            if (approvers[i] == address(0)) revert ZeroAddress();
            _grantRole(APPROVER_ROLE, approvers[i]);
        }
    }

    function submitTransaction(address to, uint256 value, bytes memory data) external payable nonReentrant onlyRole(APPROVER_ROLE) {
        uint256 txId = transactions.length;
        
        Transaction memory newTx = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            approvalCount: 0
        });
        transactions.push(newTx);
        
        emit TransactionSubmitted(txId, to, value, data);

        Transaction storage transaction = transactions[txId];
        _approveTransaction(transaction, txId);
    }

    function approveTransaction(uint256 txId) public payable nonReentrant onlyRole(APPROVER_ROLE) {
        if (txId >= transactions.length) revert InvalidTransactionId(txId);
        Transaction storage transaction = transactions[txId];
        _approveTransaction(transaction, txId);
    }

    function _approveTransaction(Transaction storage transaction, uint256 txId) private {
        if (approvals[txId][msg.sender]) revert TransactionAlreadyApproved(txId, msg.sender);

        approvals[txId][msg.sender] = true;
        transaction.approvalCount++;

        emit TransactionApproved(txId, msg.sender);

        if (transaction.approvalCount >= requiredApprovals) {
            _executeTransaction(transaction, txId);
        }
    }

    function _executeTransaction(Transaction storage transaction, uint256 txId) internal {
        if (transaction.executed) revert TransactionAlreadyExecuted(txId);
        
        transaction.executed = true;
        
        (bool success, bytes memory returndata) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        Address.verifyCallResult(success, returndata);
        
        emit TransactionExecuted(txId);
    }

    function grantRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) onlyRole(getRoleAdmin(role)) {
        if (role == APPROVER_ROLE) {
            uint256 currentCount = getRoleMemberCount(APPROVER_ROLE);
            if (currentCount >= MAX_APPROVERS) revert MaxApproversReached(MAX_APPROVERS);
        }
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) onlyRole(getRoleAdmin(role)) {
        if (role == APPROVER_ROLE) {
            uint256 currentCount = getRoleMemberCount(APPROVER_ROLE);
            if (currentCount <= requiredApprovals) 
                revert InsufficientApprovers(requiredApprovals, currentCount);
        }
        _revokeRole(role, account);
    }

    function setRequiredApprovals(uint256 _requiredApprovals) public onlyRole(ADMIN_ROLE) {
        uint256 currentCount = getRoleMemberCount(APPROVER_ROLE);
        if (_requiredApprovals < MIN_APPROVERS) revert RequiredApprovalsTooLow(_requiredApprovals, MIN_APPROVERS);
        if (_requiredApprovals > currentCount) revert RequiredApprovalsExceedApprovers(_requiredApprovals, currentCount);
        
        uint256 oldRequired = requiredApprovals;
        requiredApprovals = _requiredApprovals;
        emit RequiredApprovalsChanged(oldRequired, _requiredApprovals);
    }

    function getApproversCount() public view returns (uint256) {
        return getRoleMemberCount(APPROVER_ROLE);
    }

    /// @notice Aggregate calls, ensuring each returns success if required
    /// @param calls An array of Call3 structs
    /// @return returnData An array of Result structs
    function aggregate3(Call3[] calldata calls) public payable onlyRole(ADMIN_ROLE) returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3 calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x64)
                }
            }
            unchecked { ++i; }
        }
    }

    /// @notice Aggregate calls with a msg value
    /// @notice Reverts if msg.value is less than the sum of the call values
    /// @param calls An array of Call3Value structs
    /// @return returnData An array of Result structs
    function aggregate3Value(Call3Value[] calldata calls) public payable onlyRole(ADMIN_ROLE) returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked { valAccumulator += val; }
            (result.success, result.returnData) = calli.target.call{value: val}(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x84)
                }
            }
            unchecked { ++i; }
        }
        // Finally, make sure the msg.value = SUM(call[0...i].value)
        require(msg.value == valAccumulator, "Multicall3: value mismatch");
    }

    /// @notice Returns the block hash for the given block number
    /// @param blockNumber The block number
    function getBlockHash(uint256 blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }

    /// @notice Returns the block number
    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    /// @notice Returns the block coinbase
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    /// @notice Returns the block difficulty
    function getCurrentBlockDifficulty() public view returns (uint256 difficulty) {
        difficulty = block.difficulty;
    }

    /// @notice Returns the block gas limit
    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }

    /// @notice Returns the block timestamp
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }

    /// @notice Returns the (ETH) balance of a given address
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    /// @notice Returns the block hash of the last block
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        unchecked {
            blockHash = blockhash(block.number - 1);
        }
    }

    /// @notice Gets the base fee of the given block
    /// @notice Can revert if the BASEFEE opcode is not implemented by the given chain
    function getBasefee() public view returns (uint256 basefee) {
        basefee = block.basefee;
    }

    /// @notice Returns the chain id
    function getChainId() public view returns (uint256 chainid) {
        chainid = block.chainid;
    }

    receive() external payable {}
}