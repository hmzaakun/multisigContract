// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Multisig.sol";

contract MultisigDeployScript is Script {
    WalletMultisig public wallet;

    function run() external {
        // Lecture des variables de déploiement depuis l'environnement
        address signer1 = vm.envAddress("SIGNER1");
        address signer2 = vm.envAddress("SIGNER2");

        // Validation des adresses fournies
        require(signer1 != address(0), "SIGNER1 cannot be zero address");
        require(signer2 != address(0), "SIGNER2 cannot be zero address");
        require(signer1 != signer2, "SIGNER1 and SIGNER2 must be different");

        // Démarrage de la diffusion de la transaction
        vm.startBroadcast();

        // Déploiement du contrat multisignature
        wallet = new WalletMultisig(signer1, signer2);

        // Fin de la diffusion
        vm.stopBroadcast();

        // Affichage de l'adresse du contrat déployé
        console.log("WalletMultisig deployed at:", address(wallet));
    }
}
