// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { FactoryTokenContract } from "./FactoryTokenContract.sol";

/**
 * @title MultiSigContract.
 * @author CraftMeme.
 * @notice This contract handles the multiple signatures required for launching a memecoin using CraftMeme.
 * @dev Has volatile storage, FactoryStorageContract has persistent storage.
 * @dev This means past signed txs data isnt available in this contract after tx is executed.
 */
contract MultiSigContract is Ownable {
    FactoryTokenContract public factoryTokenContract;

    struct TxData {
        uint256 txId;
        address owner;
        address[] signers;
        bytes[] signatures;
    }

    mapping(uint256 => TxData) public pendingTxs;

    constructor() Ownable(msg.sender) { }

    function setFactoryTokenContract(address _factoryTokenContract) external onlyOwner {
        factoryTokenContract = FactoryTokenContract(_factoryTokenContract);
    }

    /**
     * @notice Creates a new pending transaction.
     * @notice Only callable by the FactoryTokenContract.
     */
    function queueTx(uint256 _txId, address _owner, address[] memory _signers) external {
        TxData memory tempTx = TxData({ txId: _txId, owner: _owner, signers: _signers, signatures: new bytes[](0) });
        pendingTxs[_txId] = tempTx;
    }

    function signTx(uint256 _txId) external {
        if (pendingTxs[_txId].signatures.length == (pendingTxs[_txId].signers.length - 1)) {
            factoryTokenContract.executeCreateMemecoin(_txId);
            delete pendingTxs[_txId];
        }
    }

    function unsignTx() external { }
}
