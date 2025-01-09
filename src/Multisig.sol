// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

/// @title Multisignature Wallet
/// @notice A wallet requiring multiple signatures for transactions.
/// @dev This contract supports adding/removing signers and managing transactions with confirmations.
contract WalletMultisig {
    /// @notice List of current signers.
    address[] public signers;

    /// @notice Number of confirmations required for a transaction to be executed.
    uint256 public requiredConfirmations;

    /// @notice A transaction structure.
    /// @param to Address of the transaction recipient.
    /// @param value Amount of Ether to transfer.
    /// @param data Transaction data (e.g., function call).
    /// @param executed Indicates if the transaction has been executed.
    /// @param confirmations Number of confirmations received for this transaction.
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    /// @notice Mapping of transaction confirmations by signers.
    /// @dev confirmations[transactionId][signer] indicates if a signer confirmed a transaction.
    mapping(uint256 => mapping(address => bool)) public confirmations;

    /// @notice Array of all transactions.
    Transaction[] public transactions;

    /// @notice Emitted when a transaction is submitted.
    /// @param txId ID of the submitted transaction.
    /// @param proposer Address of the signer who submitted the transaction.
    event TransactionSubmitted(uint256 txId, address indexed proposer);

    /// @notice Emitted when a transaction is confirmed.
    /// @param txId ID of the confirmed transaction.
    /// @param confirmer Address of the signer who confirmed the transaction.
    event TransactionConfirmed(uint256 txId, address indexed confirmer);

    /// @notice Emitted when a confirmation is revoked.
    /// @param txId ID of the transaction for which the confirmation was revoked.
    /// @param revoker Address of the signer who revoked their confirmation.
    event TransactionRevoked(uint256 txId, address indexed revoker);

    /// @notice Emitted when a transaction is executed.
    /// @param txId ID of the executed transaction.
    event TransactionExecuted(uint256 txId);

    /// @notice Emitted when a new signer is added.
    /// @param newSigner Address of the new signer.
    event SignerAdded(address newSigner);

    /// @notice Emitted when a signer is removed.
    /// @param removedSigner Address of the removed signer.
    event SignerRemoved(address removedSigner);

    /// @notice Restricts access to current signers.
    modifier onlySigner() {
        require(isSigner(msg.sender), "Not a signer");
        _;
    }

    /// @notice Ensures a transaction exists.
    /// @param txId ID of the transaction.
    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "Transaction does not exist");
        _;
    }

    /// @notice Ensures a transaction has not been executed.
    /// @param txId ID of the transaction.
    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "Transaction already executed");
        _;
    }

    /// @notice Ensures a transaction has not already been confirmed by the caller.
    /// @param txId ID of the transaction.
    modifier notConfirmed(uint256 txId) {
        require(!confirmations[txId][msg.sender], "Transaction already confirmed");
        _;
    }

    /// @notice Deploys the wallet with the initial signers and required confirmations.
    /// @param signer1 Address of the first signer.
    /// @param signer2 Address of the second signer.
    constructor(address signer1, address signer2) {
        require(signer1 != address(0) && signer2 != address(0), "Invalid signer address");
        require(signer1 != signer2, "Signers must be distinct");

        signers.push(msg.sender);
        signers.push(signer1);
        signers.push(signer2);

        requiredConfirmations = 2;
    }

    /// @notice Checks if an address is a signer.
    /// @param _account Address to check.
    /// @return True if the address is a signer, false otherwise.
    function isSigner(address _account) public view returns (bool) {
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _account) {
                return true;
            }
        }
        return false;
    }

    /// @notice Submits a new transaction for approval.
    /// @param _to Address of the recipient.
    /// @param _value Amount of Ether to transfer.
    /// @param _data Transaction data (e.g., function call).
    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlySigner {
        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, confirmations: 0}));

        emit TransactionSubmitted(transactions.length - 1, msg.sender);
    }

    /// @notice Confirms a transaction.
    /// @param txId ID of the transaction to confirm.
    function confirmTransaction(uint256 txId) public onlySigner txExists(txId) notExecuted(txId) notConfirmed(txId) {
        confirmations[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;

        emit TransactionConfirmed(txId, msg.sender);
    }

    /// @notice Revokes a confirmation for a transaction.
    /// @param txId ID of the transaction to revoke confirmation for.
    function revokeConfirmation(uint256 txId) public onlySigner txExists(txId) notExecuted(txId) {
        require(confirmations[txId][msg.sender], "Transaction not confirmed");

        confirmations[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;

        emit TransactionRevoked(txId, msg.sender);
    }

    /// @notice Executes a transaction once it has enough confirmations.
    /// @param txId ID of the transaction to execute.
    function executeTransaction(uint256 txId) public onlySigner txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];
        require(transaction.confirmations >= requiredConfirmations, "Not enough confirmations");

        transaction.executed = true;
        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(txId);
    }

    /// @notice Adds a new signer to the wallet.
    /// @param newSigner Address of the new signer.
    function addSigner(address newSigner) public onlySigner {
        require(newSigner != address(0), "Invalid address");
        require(!isSigner(newSigner), "Already a signer");

        signers.push(newSigner);

        emit SignerAdded(newSigner);
    }

    /// @notice Removes a signer from the wallet.
    /// @param signerToRemove Address of the signer to remove.
    function removeSigner(address signerToRemove) public onlySigner {
        require(isSigner(signerToRemove), "Not a signer");
        require(signers.length > 3, "Cannot have less than 3 signers");

        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signerToRemove) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        if (requiredConfirmations > signers.length) {
            requiredConfirmations = signers.length;
        }

        emit SignerRemoved(signerToRemove);
    }

    /// @notice Gets the number of current signers.
    /// @return The number of signers.
    function getSignersLength() public view returns (uint256) {
        return signers.length;
    }

    /// @notice Fallback function to receive Ether.
    receive() external payable {}

    /// @notice Fallback function for invalid calls.
    fallback() external payable {}
}
