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
}
