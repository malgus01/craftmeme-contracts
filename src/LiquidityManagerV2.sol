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

    /// @notice Pool information by token pair
    mapping(bytes32 => PoolInfo) public poolInfo;

    /// @notice User positions
    mapping(address => LiquidityPosition[]) public userPositions;

    /// @notice Supported tokens for liquidity provision
    mapping(address => bool) public supportedTokens;

    /// @notice Pool keys for easy access
    mapping(bytes32 => PoolKey) public poolKeys;

    /// @notice Token pair to pool ID mapping
    mapping(address => mapping(address => bytes32)) public tokenPairToPoolId;

    ////////////////////
    // Events //
    ////////////////////

    event PoolInitialized(
        address indexed token0,
        address indexed token1,
        bytes32 indexed poolId,
        uint24 fee,
        uint160 startingPrice,
        uint256 timestamp
    );

    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        bytes32 poolId,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        uint256 timestamp
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        bytes32 poolId,
        uint256 amount0,
        uint256 amount1,
        uint256 timestamp
    );

    event LiquidityThresholdReached(
        address indexed token0,
        address indexed token1,
        bytes32 indexed poolId,
        uint256 totalLiquidity,
        uint256 timestamp
    );

    event VestingScheduleCreated(
        address indexed beneficiary, address indexed token, uint256 amount, uint256 duration, uint256 timestamp
    );

    event EmergencyWithdrawInitiated(address indexed provider, bytes32 indexed poolId, uint256 withdrawTime);

    event ProtocolFeeCollected(address indexed token, uint256 amount, address recipient);

    event LiquidityThresholdUpdated(bytes32 indexed poolId, uint256 oldThreshold, uint256 newThreshold);

    event SupportedTokenUpdated(address indexed token, bool supported);

    ////////////////////
    // Modifiers //
    ////////////////////

    modifier onlyFactory() {
        if (msg.sender != factoryContract) {
            revert LiquidityManager__UnauthorizedCaller();
        }
        _;
    }

    modifier validTokenPair(address token0, address token1) {
        if (token0 == address(0) || token1 == address(0) || token0 == token1) {
            revert LiquidityManager__InvalidTokenAddress();
        }
        _;
    }

    modifier onlySupportedTokens(address token0, address token1) {
        if (!supportedTokens[token0] || !supportedTokens[token1]) {
            revert LiquidityManager__TokenNotSupported();
        }
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert LiquidityManager__InvalidAmount();
        }
        _;
    }

    modifier deadlineCheck(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert LiquidityManager__DeadlineExpired();
        }
        _;
    }

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

    ////////////////////
    // External Functions //
    ////////////////////

    /**
     * @notice Initialize a new Uniswap V4 pool with enhanced parameters
     * @param token0 First token address
     * @param token1 Second token address
     * @param swapFee Pool swap fee
     * @param tickSpacing Tick spacing for the pool
     * @param startingPrice Initial price in Q64.96 format
     * @param liquidityThreshold Custom threshold for this pool
     * @param vestingDuration Custom vesting duration for this pool
     */
    function initializePool(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickSpacing,
        uint160 startingPrice,
        uint256 liquidityThreshold,
        uint256 vestingDuration
    )
        external
        onlyFactory
        validTokenPair(token0, token1)
        whenNotPaused
        returns (bytes32 poolId)
    {
        // Normalize token order
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        poolId = _getPoolId(token0, token1, swapFee);

        if (poolInfo[poolId].initialized) {
            revert LiquidityManager__PoolAlreadyInitialized();
        }

        // Validate parameters
        _validatePoolParameters(swapFee, liquidityThreshold, vestingDuration);

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        // Initialize pool in Uniswap V4
        poolManager.initialize(poolKey, startingPrice);

        // Set up pool info
        PoolInfo storage pool = poolInfo[poolId];
        pool.initialized = true;
        pool.liquidityThreshold = liquidityThreshold > 0 ? liquidityThreshold : defaultLiquidityThreshold;
        pool.vestingDuration = vestingDuration > 0 ? vestingDuration : defaultVestingDuration;
        pool.createdAt = block.timestamp;
        pool.creator = tx.origin; // Get original caller from factory

        // Store pool key and mapping
        poolKeys[poolId] = poolKey;
        tokenPairToPoolId[token0][token1] = poolId;
        tokenPairToPoolId[token1][token0] = poolId;

        emit PoolInitialized(token0, token1, poolId, swapFee, startingPrice, block.timestamp);
    }

    /**
     * @notice Add liquidity to a pool with enhanced features
     * @param token0 First token address
     * @param token1 Second token address
     * @param swapFee Pool fee tier
     * @param tickLower Lower tick boundary
     * @param tickUpper Upper tick boundary
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @param amount0Min Minimum amount of token0
     * @param amount1Min Minimum amount of token1
     * @param deadline Transaction deadline
     */
    function addLiquidity(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        validTokenPair(token0, token1)
        onlySupportedTokens(token0, token1)
        validAmount(amount0Desired)
        validAmount(amount1Desired)
        deadlineCheck(deadline)
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        // Normalize token order
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0Desired, amount1Desired) = (amount1Desired, amount0Desired);
            (amount0Min, amount1Min) = (amount1Min, amount0Min);
            (tickLower, tickUpper) = (-tickUpper, -tickLower);
        }

        bytes32 poolId = _getPoolId(token0, token1, swapFee);
        PoolInfo storage pool = poolInfo[poolId];

        if (!pool.initialized) {
            revert LiquidityManager__PoolNotInitialized();
        }

        if (pool.emergencyMode) {
            revert LiquidityManager__LiquidityLocked();
        }

        // Validate tick range
        if (tickLower >= tickUpper) {
            revert LiquidityManager__InvalidTickRange();
        }

        // Transfer tokens from user
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);

        // Calculate protocol fee
        uint256 protocolFee0 = (amount0Desired * protocolFee) / FEE_PRECISION;
        uint256 protocolFee1 = (amount1Desired * protocolFee) / FEE_PRECISION;

        // Collect protocol fees
        if (protocolFee0 > 0) {
            IERC20(token0).safeTransfer(protocolFeeRecipient, protocolFee0);
            emit ProtocolFeeCollected(token0, protocolFee0, protocolFeeRecipient);
        }
        if (protocolFee1 > 0) {
            IERC20(token1).safeTransfer(protocolFeeRecipient, protocolFee1);
            emit ProtocolFeeCollected(token1, protocolFee1, protocolFeeRecipient);
        }

        // Adjust amounts after fee
        amount0 = amount0Desired - protocolFee0;
        amount1 = amount1Desired - protocolFee1;

        // Validate minimum amounts
        if (amount0 < amount0Min || amount1 < amount1Min) {
            revert LiquidityManager__InvalidSlippage();
        }

        // Calculate liquidity (simplified calculation)
        liquidity = _calculateLiquidity(amount0, amount1);

        // Update provider data
        _updateLiquidityProvider(poolId, msg.sender, amount0 + amount1, liquidity);

        // Create position record
        _createPosition(msg.sender, token0, token1, swapFee, tickLower, tickUpper, liquidity, amount0, amount1);

        emit LiquidityAdded(msg.sender, token0, token1, poolId, amount0, amount1, liquidity, block.timestamp);
    }

    /**
     * @notice Remove liquidity from a position
     * @param token0 First token address
     * @param token1 Second token address
     * @param swapFee Pool fee tier
     * @param tickLower Lower tick boundary
     * @param tickUpper Upper tick boundary
     * @param liquidity Amount of liquidity to remove
     * @param amount0Min Minimum amount of token0 to receive
     * @param amount1Min Minimum amount of token1 to receive
     * @param deadline Transaction deadline
     */
    function removeLiquidity(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0Min, amount1Min) = (amount1Min, amount0Min);
            (tickLower, tickUpper) = (-tickUpper, -tickLower);
        }

        bytes32 poolId = _getPoolId(token0, token1, swapFee);
        PoolInfo storage pool = poolInfo[poolId];

        LiquidityProvider storage provider = pool.providers[msg.sender];

        // Check if liquidity is locked
        if (provider.lockEndTime > block.timestamp) {
            revert LiquidityManager__LiquidityLocked();
        }

        // For this example, we'll calculate proportional amounts
        // In a real implementation, you'd interact with Uniswap V4's position manager
        amount0 = (liquidity * 1e18) / 2e18; // Simplified calculation
        amount1 = (liquidity * 1e18) / 2e18; // Simplified calculation

        if (amount0 < amount0Min || amount1 < amount1Min) {
            revert LiquidityManager__InvalidSlippage();
        }

        // Update provider data
        provider.amountProvided -= (amount0 + amount1);

        // Transfer tokens back to user
        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        // Update pool total liquidity
        pool.totalLiquidity -= (amount0 + amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, poolId, amount0, amount1, block.timestamp);
    }

    /**
     * @notice Initiate emergency withdrawal (with delay)
     * @param poolId Pool identifier
     */
    function initiateEmergencyWithdraw(bytes32 poolId) external {
        PoolInfo storage pool = poolInfo[poolId];
        LiquidityProvider storage provider = pool.providers[msg.sender];

        if (provider.amountProvided == 0) {
            revert LiquidityManager__InsufficientLiquidity();
        }

        provider.emergencyWithdrawTime = block.timestamp + emergencyWithdrawDelay;

        emit EmergencyWithdrawInitiated(msg.sender, poolId, provider.emergencyWithdrawTime);
    }

    /**
     * @notice Claim vested tokens
     */
        function claimVestedTokens() external nonReentrant {
        vestingContract.release(msg.sender);
    }

        ////////////////////
    // View Functions //
    ////////////////////
}
