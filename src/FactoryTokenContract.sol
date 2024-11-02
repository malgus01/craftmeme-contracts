// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenContract} from "./helpers/TokenContract.sol";
import {MultiSigContract} from "./MultiSigContract.sol";
import {LiquidityManager} from "./LiquidityManager.sol";

/**
 * @title FactoryTokenContract.
 * @author CraftMeme.
 * @notice A contract that creates new memecoin tokens and Uniswap liquidity pools for that tokens.
 * @dev Has persistant storage, MultiSigContract has volatile storage.
 * @dev This means past signed txs data is available in this contract for more functions
 * after tx is executed.
 */
contract FactoryTokenContract is Ownable {
    ////////////////////
    // Custom Errors //
    //////////////////
    error FactoryTokenContract__onlyMultiSigContract();
    error TransactionAlreadyExecuted();
    error InvalidSignerCount();
    error InvalidSupply();
    error EmptyName();
    error EmptySymbol();

    /**
     * @notice Structs.
     */
    struct TxData {
        uint256 txId;
        address owner;
        address[] signers;
        bool isPending;
        string tokenName;
        string tokenSymbol;
        uint256 totalSupply;
        uint256 maxSupply;
        bool canMint;
        bool canBurn;
        bool supplyCapEnabled;
        address tokenAddress;
        string ipfsHash;
    }

    /**
     * @notice Variables.
     */
    MultiSigContract public multiSigContract;
    LiquidityManager public liquidityManager;
    TxData[] public txArray;
    uint256 public TX_ID;
    address public USDC_ADDRESS;

    /**
     * @notice Mappings.
     */
    mapping(address => uint256) public ownerToTxId;

    /**
     * @notice Events.
     */
    event TransactionQueued(
        uint256 indexed txId,
        address indexed owner,
        address[] signers,
        string tokenName,
        string tokenSymbol
    );

    /// @notice Emit when a new token is created
    event MemecoinCreated(
        address indexed owner,
        address indexed tokenAddress,
        string indexed name,
        string symbol,
        uint256 supply
    );

    /**
     * @notice Modifiers.
     */
    modifier onlyMultiSigContract() {
        require(
            msg.sender == address(multiSigContract),
            FactoryTokenContract__onlyMultiSigContract()
        );
        _;
    }

    /// @notice modifier to ensure only pending txs can be executed
    modifier onlyPendigTx(uint256 _txId) {
        require(txArray[_txId].isPending, TransactionAlreadyExecuted());
        _;
    }

    constructor(
        address _multiSigContract,
        address _liquidityManager,
        address _USDC,
        address initialOwner
    ) Ownable(initialOwner) {
        multiSigContract = MultiSigContract(_multiSigContract);
        liquidityManager = LiquidityManager(_liquidityManager);
        TxData memory constructorTx = TxData({
            txId: 0,
            owner: address(0),
            signers: new address[](0),
            isPending: true,
            tokenName: "",
            tokenSymbol: "",
            totalSupply: 0,
            maxSupply: 0,
            canMint: false,
            canBurn: false,
            supplyCapEnabled: false,
            tokenAddress: address(0),
            ipfsHash: ""
        });
        txArray.push(constructorTx);
        ownerToTxId[address(0)] = 0;
        TX_ID = 1;
        USDC_ADDRESS = _USDC;
    }

    /**
     * @notice Creates a pending transaction to initialize a new meme token.
     * @dev Actual token creation happens once the MultiSigContract approves the transaction.
     * @param _signers The list of signers required to approve this transaction in the MultiSigContract.
     * @param _owner The address of the token owner.
     * @param _tokenName The name of the token to be created.
     * @param _tokenSymbol The symbol of the token to be created.
     * @param _totalSupply The initial token supply.
     * @param _maxSupply The maximum token supply, if a cap is enabled.
     * @param _canMint Whether the token has minting capabilities.
     * @param _canBurn Whether the token has burning capabilities.
     * @param _supplyCapEnabled Whether the token has a supply cap.
     * @return txId The ID of the newly created transaction.
     */
    function queueCreateMemecoin(
        address[] memory _signers,
        address _owner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply,
        uint256 _maxSupply,
        bool _canMint,
        bool _canBurn,
        bool _supplyCapEnabled,
        string memory _ipfsHash
    ) external returns (uint256 txId) {
        require(_signers.length >= 2, InvalidSignerCount());
        require(bytes(_tokenName).length > 0, EmptyName());
        require(bytes(_tokenSymbol).length > 0, EmptySymbol());
        require(_totalSupply > 0, InvalidSupply());
        if (_supplyCapEnabled) {
            require(_maxSupply >= _totalSupply, InvalidSupply());
        }
        txId = _handleQueue(
            _signers,
            _owner,
            _tokenName,
            _tokenSymbol,
            _totalSupply,
            _maxSupply,
            _canMint,
            _canBurn,
            _supplyCapEnabled,
            _ipfsHash
        );
    }

    /**
     * @notice Completes the pending transaction to create the meme token after MultiSigContract approval.
     * @param _txId The ID of the transaction to be executed.
     * @dev Callable only by the MultiSigContract once all required signatures are collected.
     */
    function executeCreateMemecoin(
        uint256 _txId
    ) public onlyMultiSigContract onlyPendigTx(_txId) {
        _createMemecoin(_txId);
    }

    /**
     * @notice Fetches transaction data for a given transaction ID.
     * @param _txId The ID of the transaction to fetch.
     * @return TxData memory The transaction data for the specified ID.
     */
    function getTxData(uint256 _txId) external view returns (TxData memory) {
        return txArray[_txId];
    }

    /**
     * @notice Handles the internal queuing of memecoin creation, waiting for signatures.
     * @return txId data of the transaction
     */
    function _handleQueue(
        address[] memory _signers,
        address _owner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply,
        uint256 _maxSupply,
        bool _canMint,
        bool _canBurn,
        bool _supplyCapEnabled,
        string memory _ipfsHash
    ) internal returns (uint256 txId) {
        TxData memory tempTx = TxData({
            txId: TX_ID,
            owner: _owner,
            signers: _signers,
            isPending: true,
            tokenName: _tokenName,
            tokenSymbol: _tokenSymbol,
            totalSupply: _totalSupply,
            maxSupply: _maxSupply,
            canMint: _canMint,
            canBurn: _canBurn,
            supplyCapEnabled: _supplyCapEnabled,
            tokenAddress: address(0),
            ipfsHash: _ipfsHash
        });
        txArray.push(tempTx);
        ownerToTxId[_owner] = TX_ID;
        multiSigContract.queueTx(TX_ID, _owner, _signers);
        emit TransactionQueued(
            TX_ID,
            _owner,
            _signers,
            _tokenName,
            _tokenSymbol
        );
        txId = TX_ID;
        TX_ID += 1;
    }

    /**
     *
     * @param _txId Id of the transaction.
     * @dev Creates a new memecoin and initializes the liquidity pool for it.
     * @return newToken ERC20 memecoin.
     */
    function _createMemecoin(
        uint256 _txId
    ) internal returns (TokenContract newToken) {
        TxData memory txData = txArray[_txId];
        // Deploy new TokenContract for the memecoin
        newToken = new TokenContract(
            txData.owner,
            txData.tokenName,
            txData.tokenSymbol,
            txData.totalSupply,
            txData.maxSupply,
            txData.canMint,
            txData.canBurn,
            txData.supplyCapEnabled
        );

        // Initialize the pool for the newly created token
        liquidityManager.initializePool(
            address(newToken),
            address(USDC_ADDRESS), // USDT/USDC address
            300, // swap fee (Uniswap's fee tiers: 0.01%->100, 0.05%->500, 0.3%->3000, 1%->10000)
            60, // tick spacing (depends on fee tier: 0.01%->1, 0.05%->10, 0.3%->60, 1%->200)
            79_228_162_514_264_337_593_543_950_336 // 0.0001 starting price (Q64.96 format)
        );

        txArray[_txId].isPending = false;
        txArray[_txId].tokenAddress = address(newToken);
        // Emit the MemecoinCreated event
        emit MemecoinCreated(
            txData.owner,
            address(newToken),
            txData.tokenName,
            txData.tokenSymbol,
            txData.totalSupply
        );
    }

    /**
     * @notice Updates the address of the liquidity manager.
     * @param _liquidityManager Address of the liquidity manager.
     */
    function updateLiquidityManager(
        address _liquidityManager
    ) external onlyOwner {
        liquidityManager = LiquidityManager(_liquidityManager);
    }

    /**
     * @notice Returns the array of transactions.
     * @return TxData[].
     */
    function getTokenArray() public view returns (TxData[] memory) {
        return txArray;
    }
}
