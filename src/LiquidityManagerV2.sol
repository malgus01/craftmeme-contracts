// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { IHooks } from "v4-core/src/interfaces/IHooks.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { CurrencyLibrary, Currency } from "v4-core/src/types/Currency.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { VestingContract } from "./VestingContract.sol";

/**
 * @title LiquidityManager V2
 * @author CraftMeme
 * @notice Enhanced liquidity management contract for Uniswap V4 with comprehensive features
 * @dev Manages liquidity addition, pool initialization, vesting, and anti-rug mechanisms
 */
contract LiquidityManagerV2 is Ownable, ReentrancyGuard, Pausable {
    ////////////////////
    // Libraries //
    //////////////////
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    ////////////////////
    // Custom Errors //
    //////////////////
    error LiquidityManager__PoolAlreadyInitialized();
    error LiquidityManager__PoolNotInitialized();
    error LiquidityManager__InvalidTokenAddress();
    error LiquidityManager__InvalidAmount();
    error LiquidityManager__InsufficientLiquidity();
    error LiquidityManager__ThresholdAlreadyMet();
    error LiquidityManager__VestingAlreadySet();
    error LiquidityManager__InvalidTickRange();
    error LiquidityManager__InvalidSwapFee();
    error LiquidityManager__UnauthorizedCaller();
    error LiquidityManager__TokenNotSupported();
    error LiquidityManager__LiquidityLocked();
    error LiquidityManager__InvalidSlippage();
    error LiquidityManager__DeadlineExpired();

    ////////////////////
    // Constants //
    //////////////////

    /// @notice Supported tokens
    uint256 public constant MAX_LIQUIDITY_THRESHOLD = 1000 * 1e6; // 1000 USDC max

    /// @notice Minimum liquidity threshold to prevent dust attacks
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 10 * 1e6; // 10 USDC min

    /// @notice Vesting duration limits
    uint256 public constant MAX_VESTING_DURATION = 365 days; // 1 year max

    /// @notice Minimum vesting duration to ensure commitment
    uint256 public constant MIN_VESTING_DURATION = 30 days; // 1 month min

    /// @notice Slippage and fee precision constants
    uint256 public constant SLIPPAGE_PRECISION = 10_000; // 100% = 10000

    /// @notice Fee precision constant for protocol fees
    uint256 public constant FEE_PRECISION = 1_000_000;

    ////////////////////
    // State Variables //
    ////////////////////

    /// @notice Uniswap V4 pool manager
    IPoolManager public immutable poolManager;

    /// @notice Vesting contract for liquidity providers
    VestingContract public vestingContract;

    /// @notice Factory contract address (authorized to initialize pools)
    address public factoryContract;

    /// @notice Protocol fee recipient
    address public protocolFeeRecipient;

    /// @notice Protocol fee (in basis points, e.g., 100 = 1%)
    uint256 public protocolFee = 50; // 0.5%

    /// @notice Default liquidity threshold (20 USDC)
    uint256 public defaultLiquidityThreshold = 20 * 1e6;

    /// @notice Default vesting duration (8 months)
    uint256 public defaultVestingDuration = 8 * 30 days;

    /// @notice Emergency withdrawal delay
    uint256 public emergencyWithdrawDelay = 7 days;

    /**
     * @notice Enhanced liquidity provider structure
     */
    struct LiquidityProvider {
        uint256 amountProvided;
        uint256 lastContribution;
        uint256 totalRewards;
        bool hasVested;
        bool isEligibleForRewards;
        uint256 lockEndTime;
        uint256 emergencyWithdrawTime;
    }

    /**
     * @notice Pool information structure
     */
    struct PoolInfo {
        bool initialized;
        uint256 totalLiquidity;
        uint256 liquidityThreshold;
        uint256 vestingDuration;
        uint256 createdAt;
        address creator;
        uint256 providersCount;
        bool emergencyMode;
        mapping(address => LiquidityProvider) providers;
        address[] providersList;
    }

    /**
     * @notice Liquidity position structure
     */
    struct LiquidityPosition {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidity;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 timestamp;
        bool active;
    }

    ////////////////////
    // Mappings //
    ////////////////////
    
    ////////////////////
    // Constructor //
    ////////////////////

    constructor(
        address _poolManager,
        address _vestingContract,
        address _factoryContract,
        address _protocolFeeRecipient,
        address _initialOwner
    )
        Ownable(_initialOwner)
    {
        if (
            _poolManager == address(0) || _vestingContract == address(0) || _factoryContract == address(0)
                || _protocolFeeRecipient == address(0)
        ) {
            revert LiquidityManager__InvalidTokenAddress();
        }

        poolManager = IPoolManager(_poolManager);
        vestingContract = VestingContract(_vestingContract);
        factoryContract = _factoryContract;
        protocolFeeRecipient = _protocolFeeRecipient;
    }
}
