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
   uint256 public constant MAX_SIGNERS = 20;
       uint256 public constant MIN_SIGNERS = 2;


    ////////////////////
    // State Variables //
    ////////////////////

    /// @notice Factory token contract reference
    FactoryTokenContract public factoryTokenContract;

    /// @notice Sign Protocol instance
    ISP public spInstance;

    /// @notice Schema IDs for different attestation types
    uint64 public signatureSchemaId;
    uint64 public revocationSchemaId;
    uint64 public executionSchemaId;

    /// @notice Global signature threshold (percentage * 100, e.g., 6000 = 60%)
    uint256 public signatureThreshold = 6000; // 60% by default

    /// @notice Transaction expiry duration
    //uint256 public transactionExpiry = DEFAULT_TX_EXPIRY;

    /// @notice Emergency mode status
    bool public emergencyMode;

    /// @notice Emergency admin (can pause/unpause in emergencies)
    address public emergencyAdmin;

    ////////////////////
    // Constructor //
    ////////////////////

    constructor(
        address _spInstance,
        uint64 _signatureSchemaId,
        uint64 _revocationSchemaId,
        uint64 _executionSchemaId,
        address _emergencyAdmin,
        address _initialOwner
    )
        Ownable(_initialOwner)
    {
        if (_spInstance == address(0) || _emergencyAdmin == address(0)) {
            revert MultiSigContract__InvalidAddress();
        }

        spInstance = ISP(_spInstance);
        signatureSchemaId = _signatureSchemaId;
        revocationSchemaId = _revocationSchemaId;
        executionSchemaId = _executionSchemaId;
        emergencyAdmin = _emergencyAdmin;

        // Add owner as initial signer with admin role
        //_addSigner(_initialOwner, "admin");
    }
}
