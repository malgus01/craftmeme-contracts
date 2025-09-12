// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { FactoryTokenContract } from "./FactoryTokenContract.sol";
import { ISP } from "@signprotocol/signprotocol-evm/src/interfaces/ISP.sol";
import { Attestation } from "@signprotocol/signprotocol-evm/src/models/Attestation.sol";
import { DataLocation } from "@signprotocol/signprotocol-evm/src/models/DataLocation.sol";

/**
 * @title MultiSigContract
 * @author CraftMeme
 * @dev A multisig contract requiring multiple signers to approve transactions, adding decentralization and security.
 * Integrates Sign Protocol to manage on-chain signature attestations for enhanced transparency and validation.
 * @notice Works with FactoryTokenContract for meme token creation, with signers validating transactions.
 */
contract MultiSigContract is Ownable {
    ////////////////////
    // Custom Errors //
    //////////////////
    error MultiSigContract__onlyFactoryTokenContract();
    error MultiSigContract__onlySigner();
    error MultiSigContract__alreadySigned();

    //////////////////////
    // State variables //
    ////////////////////
    /// @notice Reference to the factory token contract used for token creation.
    FactoryTokenContract public factoryTokenContract;

    /// @notice Sign Protocol instance used for attestations.
    ISP public spInstance;

    /// @notice Unique ID for the signature schema within the Sign Protocol.
    uint64 public signatureSchemaId;

    /// @notice Structure to store transaction data for multisig approvals.
    struct TxData {
        uint256 txId; // Unique ID of the transaction
        address owner; // Owner of the transaction (token creator)
        address[] signers; // List of addresses that can sign the transaction
        address[] signatures; // List of addresses that have already signed the transaction
    }

    /// @notice Mapping of transaction ID to its corresponding transaction data.
    mapping(uint256 => TxData) public pendingTxs;

    /// @notice Mapping from signer address to their attestation ID in Sign Protocol.
    mapping(address => uint64) public signerToAttestationId;

    /**
     * @dev Modifier that ensures only the factory token contract or owner can call the function.
     */
    modifier onlyFactoryTokenContract() {
        require(
            (msg.sender == address(factoryTokenContract)) || (msg.sender == owner()),
            MultiSigContract__onlyFactoryTokenContract()
        );
        _;
    }

    /**
     * @dev Modifier restricting function access to signers of a specific transaction.
     * @param _txId The transaction ID to verify signer access.
     */
    modifier onlySigner(uint256 _txId) {
        address temp = address(0);
        for (uint256 i = 0; i < pendingTxs[_txId].signers.length; i++) {
            if (pendingTxs[_txId].signers[i] == msg.sender) {
                temp = pendingTxs[_txId].signers[i];
            }
        }
        require(temp == msg.sender, MultiSigContract__onlySigner());
        _;
    }

    /**
     * @dev Modifier to ensure a signer has not already signed the specified transaction.
     * @param _txId The transaction ID being processed.
     */
    modifier notAlreadySigned(uint256 _txId) {
        address temp = address(0);
        for (uint256 i = 0; i < pendingTxs[_txId].signatures.length; i++) {
            if (pendingTxs[_txId].signatures[i] == msg.sender) {
                temp = pendingTxs[_txId].signatures[i];
            }
        }
        require(temp == address(0), MultiSigContract__alreadySigned());
        _;
    }

    /**
     * @dev Modifier to ensure the signer has already signed the transaction.
     * @param _txId The transaction ID to verify signing status.
     */
    modifier alreadySigned(uint256 _txId) {
        address temp = address(0);
        for (uint256 i = 0; i < pendingTxs[_txId].signatures.length; i++) {
            if (pendingTxs[_txId].signatures[i] == msg.sender) {
                temp = pendingTxs[_txId].signatures[i];
            }
        }
        require(temp == msg.sender, MultiSigContract__alreadySigned());
        _;
    }

    ////////////////
    // Functions //
    //////////////
    /**
     * @param _spInstance Address of the Sign Protocol instance.
     * @param _signatureSchemaId Unique schema ID for signature verification within Sign Protocol.
     */
    constructor(address _spInstance, uint64 _signatureSchemaId) Ownable(msg.sender) {
        spInstance = ISP(_spInstance);
        signatureSchemaId = _signatureSchemaId;
    }

    /**
     * @notice Assigns the address of the FactoryTokenContract.
     * @param _factoryTokenContract Address of the factory token contract.
     * @dev Callable only by the contract owner.
     */
    function setFactoryTokenContract(address _factoryTokenContract) external onlyOwner {
        factoryTokenContract = FactoryTokenContract(_factoryTokenContract);
    }

    /**
     * @notice Adds a new transaction to the queue for multisig validation.
     * @param _txId Unique transaction ID.
     * @param _owner Address of the transaction owner.
     * @param _signers List of authorized signers for this transaction.
     * @dev Can only be called by the FactoryTokenContract.
     */
    function queueTx(uint256 _txId, address _owner, address[] memory _signers) external onlyFactoryTokenContract {
        _handleQueue(_txId, _owner, _signers);
    }

    /**
     * @notice Allows a signer to approve a queued transaction.
     * @param _txId The transaction ID to be signed.
     * @dev Ensures signer is authorized and hasn't signed yet. Creates an attestation on Sign Protocol.
     */
    function signTx(uint256 _txId) external onlySigner(_txId) notAlreadySigned(_txId) {
        _handleSign(_txId);
        _attestSign(_txId, msg.sender);
    }

    /**
     * @notice Allows a signer to revoke their approval for a transaction.
     * @param _txId The transaction ID to unsign.
     * @dev Requires prior approval from the signer. Revokes the attestation on Sign Protocol.
     */
    function unsignTx(uint256 _txId) external onlySigner(_txId) alreadySigned(_txId) {
        _handleUnSign(_txId);
        _attestRevokeSign(_txId, msg.sender);
    }

    /**
     * @param _txId The ID of the transaction.
     * @return Details of the specified transaction.
     */
    function getPendingTxData(uint256 _txId) public view returns (TxData memory) {
        return pendingTxs[_txId];
    }

    /**
     * @notice Internally handles transaction queueing.
     * @param _txId Transaction ID.
     * @param _owner Owner of the transaction.
     * @param _signers List of valid signers.
     */
    function _handleQueue(uint256 _txId, address _owner, address[] memory _signers) internal {
        TxData memory tempTx = TxData({ txId: _txId, owner: _owner, signers: _signers, signatures: new address[](0) });
        pendingTxs[_txId] = tempTx;
    }

    /**
     * @dev Internal function to manage transaction signing.
     * Executes transaction if all signers have signed.
     * @param _txId The transaction ID.
     */
    function _handleSign(uint256 _txId) internal {
        if (pendingTxs[_txId].signatures.length == (pendingTxs[_txId].signers.length - 1)) {
            factoryTokenContract.executeCreateMemecoin(_txId);
            delete pendingTxs[_txId]; // Clear the pending transaction after execution
        } else {
            pendingTxs[_txId].signatures.push(msg.sender);
        }
    }

    /**
     * @notice Internally attests the signing action on Sign Protocol.
     * @param _txId Transaction ID.
     * @param _signer Signer address.
     */
    function _attestSign(uint256 _txId, address _signer) internal {
        bytes[] memory recipients = new bytes[](1);
        recipients[0] = abi.encode(msg.sender);
        Attestation memory a = Attestation({
            schemaId: signatureSchemaId,
            linkedAttestationId: 0,
            attestTimestamp: uint64(block.timestamp),
            revokeTimestamp: 0,
            attester: address(this),
            validUntil: 0,
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: recipients,
            data: abi.encode(_txId, _signer)
        });
        uint64 attestationId = spInstance.attest(a, "", "", "");
        signerToAttestationId[_signer] = attestationId;
    }

    /**
     * @notice Internally handles the revocation of a signature attestation.
     * @param _txId Transaction ID.
     * @param _signer Signer address.
     */
    function _attestRevokeSign(uint256 _txId, address _signer) internal {
        // spInstance.revoke(
        //     signerToAttestationId[_signer],
        //     "Signer unsigned create memecoin."
        // );
    }

    /**
     * @dev Internal function to handle the revocation of a signature.
     * @param _txId The transaction ID being unsigned.
     * Removes the signer's signature from the list.
     */
    function _handleUnSign(uint256 _txId) internal {
        for (uint256 i = 0; i < pendingTxs[_txId].signatures.length; i++) {
            if (pendingTxs[_txId].signatures[i] == msg.sender) {
                delete pendingTxs[_txId].signatures[i];
            }
        }
    }
}
