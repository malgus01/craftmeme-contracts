// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { FactoryTokenContract } from "./FactoryTokenContract.sol";
import { ISP } from "@signprotocol/signprotocol-evm/src/interfaces/ISP.sol";
import { Attestation } from "@signprotocol/signprotocol-evm/src/models/Attestation.sol";
import { DataLocation } from "@signprotocol/signprotocol-evm/src/models/DataLocation.sol";

/**
 * @title MultiSigContract V2
 * @author CraftMeme
 * @notice Enhanced multisig contract with comprehensive security features and governance
 * @dev Includes timelock, emergency functions, role management, and advanced attestation features
 */
contract MultiSigContractV2 is Ownable, ReentrancyGuard, Pausable {
    ////////////////////
    // Custom Errors //
    //////////////////

    error MultiSigContract__OnlyFactoryTokenContract();
    error MultiSigContract__OnlySigner();
    error MultiSigContract__AlreadySigned();
    error MultiSigContract__NotSigned();
    error MultiSigContract__InvalidTransaction();
    error MultiSigContract__TransactionExpired();
    error MultiSigContract__TransactionNotReady();
    error MultiSigContract__InvalidSignerCount();
    error MultiSigContract__SignerAlreadyExists();
    error MultiSigContract__SignerNotFound();
    error MultiSigContract__InsufficientSignatures();
    error MultiSigContract__InvalidAddress();
    error MultiSigContract__TimelockActive();
    error MultiSigContract__EmergencyModeActive();
error MultiSigContract__InvalidThreshold();
    error MultiSigContract__DuplicateSigner();

    ////////////////////
    // Constants //
    //////////////////

    /// @notice Factory token contract reference
    FactoryTokenContract public factoryTokenContract;

    /// @notice Sign Protocol instance
    ISP public spInstance;
}
