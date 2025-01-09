// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WalletMultisig {
    address[] public signers;
    uint256 public requiredConfirmations;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    mapping(uint256 => mapping(address => bool)) public confirmations;
    Transaction[] public transactions;

    event TransactionSubmitted(uint256 txId, address indexed proposer);
    event TransactionConfirmed(uint256 txId, address indexed confirmer);
    event TransactionRevoked(uint256 txId, address indexed revoker);
    event TransactionExecuted(uint256 txId);
    event SignerAdded(address newSigner);
    event SignerRemoved(address removedSigner);

    modifier onlySigner() {
        require(isSigner(msg.sender), "Not a signer");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(
            !confirmations[txId][msg.sender],
            "Transaction already confirmed"
        );
        _;
    }

    constructor(address signer1, address signer2) {
        require(
            signer1 != address(0) && signer2 != address(0),
            "Invalid signer address"
        );
        require(signer1 != signer2, "Signers must be distinct");

        signers.push(msg.sender);
        signers.push(signer1);
        signers.push(signer2);

        requiredConfirmations = 2;
    }

    function isSigner(address _account) public view returns (bool) {
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _account) {
                return true;
            }
        }
        return false;
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlySigner {
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );

        emit TransactionSubmitted(transactions.length - 1, msg.sender);
    }

    function confirmTransaction(
        uint256 txId
    ) public onlySigner txExists(txId) notExecuted(txId) notConfirmed(txId) {
        confirmations[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;

        emit TransactionConfirmed(txId, msg.sender);
    }

    function revokeConfirmation(
        uint256 txId
    ) public onlySigner txExists(txId) notExecuted(txId) {
        require(confirmations[txId][msg.sender], "Transaction not confirmed");

        confirmations[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;

        emit TransactionRevoked(txId, msg.sender);
    }

    function executeTransaction(
        uint256 txId
    ) public onlySigner txExists(txId) notExecuted(txId) {
        Transaction storage transaction = transactions[txId];
        require(
            transaction.confirmations >= requiredConfirmations,
            "Not enough confirmations"
        );

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");

        emit TransactionExecuted(txId);
    }

    function addSigner(address newSigner) public onlySigner {
        require(newSigner != address(0), "Invalid address");
        require(!isSigner(newSigner), "Already a signer");

        signers.push(newSigner);

        emit SignerAdded(newSigner);
    }

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

    function getSignersLength() public view returns (uint256) {
        return signers.length;
    }

    receive() external payable {}

    fallback() external payable {}
}
