// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenContract } from "./helpers/TokenContract.sol";
import { MultiSigContract } from "./MultiSigContract.sol";
import { LiquidityManager } from "./LiquidityManager.sol";
import { VestingContract } from "./VestingContract.sol";

/**
 * @title FactoryTokenContractV2
 * @author CraftMeme
 * @notice An improved contract for creating memecoin tokens with enhanced security and features
 * @dev Includes reentrancy protection, pausability, better gas optimization, and comprehensive validation
 */
contract FactoryTokenContractV2 is Ownable, ReentrancyGuard, Pausable {
    ////////////////////
    // Custom Errors //
    //////////////////
    error FactoryTokenContract__OnlyMultiSigContract();
    error FactoryTokenContract__TransactionAlreadyExecuted();
    error FactoryTokenContract__InvalidSignerCount();
    error FactoryTokenContract__InvalidSupply();
    error FactoryTokenContract__EmptyName();
    error FactoryTokenContract__EmptySymbol();
    error FactoryTokenContract__InvalidOwner();
    error FactoryTokenContract__InvalidIPFSHash();
    error FactoryTokenContract__TransactionNotFound();
    error FactoryTokenContract__InvalidAddress();
    error FactoryTokenContract__DuplicateSigner();
    error FactoryTokenContract__NameTooLong();
    error FactoryTokenContract__SymbolTooLong();
    error FactoryTokenContract__TotalSupplyTooHigh();
    error FactoryTokenContract__InsufficientLiquidity();

    ////////////////////
    // State Variables //
    ///////////////////
    
    /// @notice Maximum values for validation
    uint256 public constant MAX_SIGNERS = 10;
    uint256 public constant MIN_SIGNERS = 2;
    uint256 public constant MAX_NAME_LENGTH = 50;
    uint256 public constant MAX_SYMBOL_LENGTH = 10;
    uint256 public constant MAX_TOTAL_SUPPLY = 1e15 * 1e18; // 1 quadrillion tokens max
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 20 * 1e6; // 20 USDC (assuming 6 decimals)

    /// @notice Fee configuration
    uint256 public creationFee = 0.001 ether; // Fee in ETH for creating tokens
    address public feeRecipient;

    /**
     * @notice Enhanced transaction data structure
     */
    struct TransactionData {
        uint256 txId;
        address owner;
        address[] signers;
        bool isPending;
        bool isExecuted;
        string tokenName;
        string tokenSymbol;
        uint256 totalSupply;
        uint256 maxSupply;
        bool canMint;
        bool canBurn;
        bool supplyCapEnabled;
        address tokenAddress;
        string ipfsHash;
        uint256 createdAt;
        uint256 executedAt;
        uint256 liquidityProvided;
    }

    /**
     * @notice Liquidity threshold tracking
     */
    struct LiquidityInfo {
        uint256 totalLiquidity;
        bool thresholdMet;
        address[] contributors;
        mapping(address => uint256) contributions;
    }

    ////////////////////
    // Storage //
    ///////////////////

    /// @notice All transactions
    TransactionData[] public transactions;

    /// @notice Mappings for efficient lookups
    mapping(address => uint256[]) public ownerToTxIds;
    mapping(address => bool) public isTokenCreated;
    mapping(address => LiquidityInfo) public tokenLiquidity;
    mapping(address => address) public tokenToOwner;

    ////////////////////
    // Events //
    ///////////////////
    event TransactionQueued(
        uint256 indexed txId,
        address indexed owner,
        address[] signers,
        string tokenName,
        string tokenSymbol,
        uint256 timestamp
    );

    event MemecoinCreated(
        address indexed owner,
        address indexed tokenAddress,
        string indexed name,
        string symbol,
        uint256 supply,
        uint256 timestamp
    );

    event LiquidityProvided(
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 timestamp
    );

    event LiquidityThresholdMet(
        address indexed token,
        uint256 totalLiquidity,
        uint256 timestamp
    );

    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event ContractUpgraded(string component, address oldAddress, address newAddress);

    ////////////////////
    // Modifiers //
    ///////////////////

    modifier onlyMultiSigContract() {
        if (msg.sender != address(multiSigContract)) {
            revert FactoryTokenContract__OnlyMultiSigContract();
        }
        _;
    }

    modifier onlyPendingTx(uint256 _txId) {
        if (_txId >= transactions.length || !transactions[_txId].isPending) {
            revert FactoryTokenContract__TransactionAlreadyExecuted();
        }
        _;
    }

    modifier validTxId(uint256 _txId) {
        if (_txId >= transactions.length) {
            revert FactoryTokenContract__TransactionNotFound();
        }
        _;
    }

    modifier onlyValidOwner(address _owner) {
        if (_owner == address(0)) {
            revert FactoryTokenContract__InvalidOwner();
        }
        _;
    }

    ////////////////////
    // Constructor //
    ///////////////////

    constructor(
        address _multiSigContract,
        address _liquidityManager,
        address _vestingContract,
        address _usdc,
        address _feeRecipient,
        address _initialOwner
    ) Ownable(_initialOwner) {
        if (_multiSigContract == address(0) || 
            _liquidityManager == address(0) || 
            _vestingContract == address(0) ||
            _usdc == address(0) || 
            _feeRecipient == address(0)) {
            revert FactoryTokenContract__InvalidAddress();
        }

        multiSigContract = MultiSigContract(_multiSigContract);
        liquidityManager = LiquidityManager(_liquidityManager);
        vestingContract = VestingContract(_vestingContract);
        USDC = IERC20(_usdc);
        feeRecipient = _feeRecipient;

        // Initialize with dummy transaction at index 0 for easier indexing
        transactions.push(TransactionData({
            txId: 0,
            owner: address(0),
            signers: new address[](0),
            isPending: false,
            isExecuted: false,
            tokenName: "",
            tokenSymbol: "",
            totalSupply: 0,
            maxSupply: 0,
            canMint: false,
            canBurn: false,
            supplyCapEnabled: false,
            tokenAddress: address(0),
            ipfsHash: "",
            createdAt: block.timestamp,
            executedAt: 0,
            liquidityProvided: 0
        }));
    }

    ////////////////////
    // External Functions //
    ////////////////////

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
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyValidOwner(_owner)
        returns (uint256 txId)
    {
        // Validate fee payment
        if (msg.value < creationFee) {
            revert FactoryTokenContract__InsufficientLiquidity();
        }

        // Validate input parameters
        _validateTokenParameters(_signers, _tokenName, _tokenSymbol, _totalSupply, _maxSupply, _supplyCapEnabled, _ipfsHash);

        // Create transaction
        txId = _createTransaction(
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

        // Queue in multisig contract
        multiSigContract.queueTx(txId, _owner, _signers);

        // Transfer fee
        if (msg.value > 0) {
            (bool success, ) = feeRecipient.call{value: msg.value}("");
            require(success, "Fee transfer failed");
        }

        emit TransactionQueued(txId, _owner, _signers, _tokenName, _tokenSymbol, block.timestamp);
    }
}
