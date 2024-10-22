// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
/**
 * @title FactoryTokenContract.
 * @author CraftMeme.
 * @dev Has persistant storage, MultiSigContract has volatile storage.
 * @dev This means past signed txs data is available in this contract for more functions
 * after tx is executed.
 */
import {TokenContract} from "./TokenContract.sol";
import {MultiSigContract} from "./MultiSigContract.sol";

contract FactoryTokenContract {
    uint256 TX_ID;
    MultiSigContract public multiSigContract;

    struct TxData {
        uint256 txId;
        address owner;
        address[] signers;
        bool isPending;
        string tokenName;
        string tokenSymbol;
        uint256 totalSupply;
    }

    TxData[] public txArray;
    mapping(address => uint256) public ownerToTxId;

    constructor(address _multiSigContract) {
        multiSigContract = MultiSigContract(_multiSigContract);
        TxData memory constructorTx = TxData({
            txId: 0,
            owner: address(0),
            signers: new address[](0),
            isPending: true,
            tokenName: "",
            tokenSymbol: "",
            totalSupply: 0
        });
        txArray.push(constructorTx);
        ownerToTxId[address(0)] = 0;
        TX_ID = 1;
    }

    /**
     * @notice Only adds a pending tx to create a new memecoin.
     * @notice Tx is completed when all of the signers approve the tx in the MultiSigContract.
     * @dev Creates a new pending tx in MultiSigContract.
     * @dev When all the signers complete the signature in MultiSigContract, the MSC calls executeTx()
     * to complete the tx and create a new memecoin.
     * @dev This function does not add any liquidity or such, that is done by separate functions.
     * @dev One memecoin can only have one on paper owner, but the other owner's data is always saved
     * in this contract.
     */
    function queueCreateMemecoin(
        address[] memory _signers,
        address _owner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply
    ) external returns (uint256 txId) {
        TxData memory tempTx = TxData({
            txId: TX_ID,
            owner: _owner,
            signers: _signers,
            isPending: true,
            tokenName: _tokenName,
            tokenSymbol: _tokenSymbol,
            totalSupply: _totalSupply
        });
        txArray.push(tempTx);
        ownerToTxId[_owner] = TX_ID;
        multiSigContract.queueTx(txArray[TX_ID].txId, _owner, _signers);
        txId = TX_ID;
        TX_ID += 1;
    }

    /**
     * @notice Executes the pending tx in MultiSigContract after all signers have signed the tx.
     * @notice Memecoin has been created when this function is called.
     * @dev This function is only callable by the MultiSigContract.
     */
    function executeCreateMemecoin(uint256 _txId) public {}
}
