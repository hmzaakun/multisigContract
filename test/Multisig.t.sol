// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Multisig.sol";

contract MultisigTest is Test {
    WalletMultisig public wallet;
    address public signer1 = address(0x123);
    address public signer2 = address(0x456);
    address public nonSigner = address(0x789);

    function setUp() public {
        wallet = new WalletMultisig(signer1, signer2);
    }

    function testInitialSetup() public view {
        assertEq(
            wallet.isSigner(address(this)),
            true,
            "Deployer should be a signer"
        );
        assertEq(wallet.isSigner(signer1), true, "Signer1 should be a signer");
        assertEq(wallet.isSigner(signer2), true, "Signer2 should be a signer");
        assertEq(
            wallet.isSigner(nonSigner),
            false,
            "Non-signer should not be a signer"
        );
        assertEq(
            wallet.requiredConfirmations(),
            2,
            "Required confirmations should be 2"
        );
    }

    function testSubmitTransaction() public {
        wallet.submitTransaction(address(0x111), 1 ether, "");
        (
            address to,
            uint256 value,
            ,
            bool executed,
            uint256 confirmations
        ) = wallet.transactions(0);

        assertEq(to, address(0x111), "Transaction recipient incorrect");
        assertEq(value, 1 ether, "Transaction value incorrect");
        assertEq(executed, false, "Transaction should not be executed yet");
        assertEq(confirmations, 0, "Transaction should have 0 confirmations");
    }

    function testConfirmTransaction() public {
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);

        (, , , bool executed, uint256 confirmations) = wallet.transactions(0);
        assertEq(confirmations, 1, "Transaction should have 1 confirmation");
        assertEq(executed, false, "Transaction should not be executed yet");
    }

    function testRevokeConfirmation() public {
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);
        vm.prank(signer1);
        wallet.revokeConfirmation(0);

        (, , , bool executed, uint256 confirmations) = wallet.transactions(0);
        assertEq(
            confirmations,
            0,
            "Transaction should have 0 confirmations after revocation"
        );
        assertEq(executed, false, "Transaction should not be executed");
    }

    function testExecuteTransaction() public {
        vm.deal(address(wallet), 1 ether); // Fund the wallet
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        wallet.executeTransaction(0);

        (, , , bool executed, ) = wallet.transactions(0);
        assertEq(executed, true, "Transaction should be executed");
    }

    function testAddSigner() public {
        address newSigner = address(0xABC);
        wallet.addSigner(newSigner);

        assertEq(
            wallet.isSigner(newSigner),
            true,
            "New signer should be added"
        );
    }

    function testRemoveSigner() public {
        wallet.addSigner(address(0xABC)); // Add a new signer to maintain 3 signers
        wallet.removeSigner(signer2);

        assertEq(wallet.isSigner(signer2), false, "Signer2 should be removed");
        assertEq(
            wallet.getSignersLength(),
            3,
            "Signers list should have 3 members"
        );
    }

    function testSubmitTransactionWithZeroValue() public {
        wallet.submitTransaction(address(0x111), 0 ether, "");
        (, uint256 value, , , ) = wallet.transactions(0);

        assertEq(value, 0 ether, "Transaction value should be zero");
    }

    function test_RevertWhen_AddDuplicateSigner() public {
        vm.expectRevert("Already a signer");
        wallet.addSigner(signer1);
    }

    function test_RevertWhen_AddInvalidSigner() public {
        vm.expectRevert("Invalid address");
        wallet.addSigner(address(0));
    }

    function test_RevertWhen_RemoveNonSigner() public {
        vm.expectRevert("Not a signer");
        wallet.removeSigner(nonSigner);
    }

    function test_RevertWhen_RemoveBelowThreshold() public {
        wallet.addSigner(address(0xABC));
        wallet.removeSigner(signer2);

        vm.expectRevert("Cannot have less than 3 signers");
        wallet.removeSigner(signer1);
    }

    function test_RevertWhen_TransactionDoesNotExist() public {
        vm.expectRevert("Transaction does not exist");
        wallet.confirmTransaction(999);
    }

    function test_RevertWhen_TransactionAlreadyConfirmed() public {
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);

        vm.prank(signer1);
        vm.expectRevert("Transaction already confirmed");
        wallet.confirmTransaction(0);
    }

    function test_RevertWhen_ExecuteWithoutEnoughConfirmations() public {
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);

        vm.expectRevert("Not enough confirmations");
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_TransactionAlreadyExecuted() public {
        vm.deal(address(wallet), 1 ether);
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);
        vm.prank(signer2);
        wallet.confirmTransaction(0);
        wallet.executeTransaction(0);

        vm.expectRevert("Transaction already executed");
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_TransactionFails() public {
        wallet.submitTransaction(address(0x111), 1 ether, ""); // Insufficient funds
        vm.prank(signer1);
        wallet.confirmTransaction(0);
        vm.prank(signer2);
        wallet.confirmTransaction(0);

        vm.expectRevert("Transaction failed");
        wallet.executeTransaction(0);
    }
}
