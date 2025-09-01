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

    /**
     * @notice Creates a pending transaction to initialize a new meme token
     * @param _signers Array of addresses that need to sign the transaction
     * @param _owner Address of the token owner
     * @param _tokenName Name of the token
     * @param _tokenSymbol Symbol of the token
     * @param _totalSupply Initial token supply
     * @param _maxSupply Maximum token supply (if cap enabled)
     * @param _canMint Whether token can be minted
     * @param _canBurn Whether token can be burned
     * @param _supplyCapEnabled Whether supply cap is enabled
     * @param _ipfsHash IPFS hash for token metadata
     * @return txId The ID of the created transaction
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

    /**
     * @notice Executes a pending transaction after multisig approval
     * @param _txId ID of the transaction to execute
     */
    function executeCreateMemecoin(uint256 _txId) 
        external 
        onlyMultiSigContract 
        onlyPendingTx(_txId) 
        nonReentrant 
    {
        TransactionData storage txData = transactions[_txId];
        
        // Create the token
        TokenContract newToken = _deployToken(txData);
        
        // Update transaction status
        txData.isPending = false;
        txData.isExecuted = true;
        txData.tokenAddress = address(newToken);
        txData.executedAt = block.timestamp;
        
        // Update tracking
        isTokenCreated[address(newToken)] = true;
        tokenToOwner[address(newToken)] = txData.owner;
        totalTokensCreated++;
        
        // Initialize liquidity pool
        _initializeLiquidityPool(address(newToken));
        
        emit MemecoinCreated(
            txData.owner, 
            address(newToken), 
            txData.tokenName, 
            txData.tokenSymbol, 
            txData.totalSupply,
            block.timestamp
        );
    }

    /**
     * @notice Provides liquidity for a token
     * @param _tokenAddress Address of the token
     * @param _usdcAmount Amount of USDC to provide
     */
    function provideLiquidity(address _tokenAddress, uint256 _usdcAmount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        if (!isTokenCreated[_tokenAddress]) {
            revert FactoryTokenContract__InvalidAddress();
        }

        // Transfer USDC from user
        USDC.transferFrom(msg.sender, address(this), _usdcAmount);
        
        // Update liquidity tracking
        LiquidityInfo storage liquidityInfo = tokenLiquidity[_tokenAddress];
        
        if (liquidityInfo.contributions[msg.sender] == 0) {
            liquidityInfo.contributors.push(msg.sender);
        }
        
        liquidityInfo.contributions[msg.sender] += _usdcAmount;
        liquidityInfo.totalLiquidity += _usdcAmount;
        
        // Check if threshold is met
        if (!liquidityInfo.thresholdMet && liquidityInfo.totalLiquidity >= MIN_LIQUIDITY_THRESHOLD) {
            liquidityInfo.thresholdMet = true;
            emit LiquidityThresholdMet(_tokenAddress, liquidityInfo.totalLiquidity, block.timestamp);
        }
        
        emit LiquidityProvided(_tokenAddress, msg.sender, _usdcAmount, block.timestamp);
    }

    ////////////////////
    // View Functions //
    ////////////////////

    /**
     * @notice Get transaction data by ID
     * @param _txId Transaction ID
     * @return Transaction data
     */
    function getTransaction(uint256 _txId) external view validTxId(_txId) returns (TransactionData memory) {
        return transactions[_txId];
    }

    /**
     * @notice Get all transactions for an owner
     * @param _owner Owner address
     * @return Array of transaction IDs
     */
    function getOwnerTransactions(address _owner) external view returns (uint256[] memory) {
        return ownerToTxIds[_owner];
    }

    /**
     * @notice Get total number of transactions
     * @return Total transaction count
     */
    function getTotalTransactions() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @notice Get liquidity information for a token
     * @param _tokenAddress Token address
     * @return totalLiquidity Total liquidity provided
     * @return thresholdMet Whether threshold is met
     * @return contributorCount Number of contributors
     */
    function getLiquidityInfo(address _tokenAddress) 
        external 
        view 
        returns (uint256 totalLiquidity, bool thresholdMet, uint256 contributorCount) 
    {
        LiquidityInfo storage info = tokenLiquidity[_tokenAddress];
        return (info.totalLiquidity, info.thresholdMet, info.contributors.length);
    }

    /**
     * @notice Get user's contribution to a token's liquidity
     * @param _tokenAddress Token address
     * @param _user User address
     * @return User's contribution amount
     */
    function getUserContribution(address _tokenAddress, address _user) external view returns (uint256) {
        return tokenLiquidity[_tokenAddress].contributions[_user];
    }

    ////////////////////
    // Admin Functions //
    ////////////////////

    /**
     * @notice Update creation fee
     * @param _newFee New creation fee
     */
    function updateCreationFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = creationFee;
        creationFee = _newFee;
        emit CreationFeeUpdated(oldFee, _newFee);
    }

    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == address(0)) {
            revert FactoryTokenContract__InvalidAddress();
        }
        address oldRecipient = feeRecipient;
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(oldRecipient, _newRecipient);
    }
}
