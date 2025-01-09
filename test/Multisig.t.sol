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

    function testInitialSetup() public {
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

        (
            address to,
            uint256 value,
            ,
            bool executed,
            uint256 confirmations
        ) = wallet.transactions(0);
        assertEq(confirmations, 1, "Transaction should have 1 confirmation");
        assertEq(executed, false, "Transaction should not be executed yet");
    }

    function testRevokeConfirmation() public {
        wallet.submitTransaction(address(0x111), 1 ether, "");
        vm.prank(signer1);
        wallet.confirmTransaction(0);
        vm.prank(signer1);
        wallet.revokeConfirmation(0);

        (
            address to,
            uint256 value,
            ,
            bool executed,
            uint256 confirmations
        ) = wallet.transactions(0);
        assertEq(
            confirmations,
            0,
            "Transaction should have 0 confirmations after revocation"
        );
        assertEq(executed, false, "Transaction should not be executed");
    }

    function testExecuteTransaction() public {
        vm.deal(address(wallet), 1 ether); // Ajoute 1 ether au contrat
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
        wallet.addSigner(address(0xABC)); // Ajoute un nouveau signataire pour maintenir 3 signataires minimum après suppression
        wallet.removeSigner(signer2);

        assertEq(wallet.isSigner(signer2), false, "Signer2 should be removed");
        assertEq(
            wallet.getSignersLength(),
            3,
            "Signers list should have 3 members"
        );
    }

    function testFailAddDuplicateSigner() public {
        wallet.addSigner(signer1); // Should fail since signer1 is already a signer
    }

    function testFailRemoveBelowThreshold() public {
        wallet.removeSigner(signer1);
        wallet.removeSigner(signer2); // Should fail since it will reduce signers below 3
    }

    function testFailNonSignerActions() public {
        vm.prank(nonSigner);
        wallet.submitTransaction(address(0x111), 1 ether, ""); // Should fail
    }
}
