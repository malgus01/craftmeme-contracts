// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { IHooks } from "v4-core/src/interfaces/IHooks.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { CurrencyLibrary, Currency } from "v4-core/src/types/Currency.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VestingContract } from "./VestingContract.sol";

/**
 * @title LiquidityManager
 * @author CraftMeme
 * @dev Manages liquidity addition and pool initialization for Uniswap V4, with a vesting system for liquidity
 * providers.
 * @notice Enables liquidity providers to add liquidity to Uniswap V4 pools and access token vesting after a threshold
 * is met.
 */
contract LiquidityManager {
    ////////////////////
    // Custom Errors //
    //////////////////
    error PoolAlreadyInitialized();
    error PoolNotInitialized();

    //////////////////////
    // State variables //
    ////////////////////
    /// @notice SafeERC20 is used for token transfers
    using SafeERC20 for IERC20;

    /// @notice Currency is used for token calculations
    using CurrencyLibrary for Currency;

    /// @notice Uniswap V4 pool manager
    IPoolManager public poolManager;

    /// @notice Vesting contract for liquidity providers
    VestingContract public vestingContract;

    /// @notice Struct to store liquidity provider data
    struct LiquidityProvider {
        uint256 amountProvided;
        bool hasVested;
    }

    /// @notice Liquidity threshold for vesting
    uint256 public liquidityThreshold = 2 * 1e6; // 20 USDT or USDC

    /// @notice Mapping of liquidity providers to their liquidity data
    mapping(address => mapping(address => LiquidityProvider)) public liquidityProviders;

    /// @notice Mapping of tokens to whether the pool has been initialized
    mapping(address => bool) public poolInitialized;

    /////////////
    // Events //
    ///////////
    /// @notice Emit when a new pool is initialized
    event PoolInitialized(address indexed token0, address indexed token1, address indexed pool);

    /// @notice Emit when liquidity is added to a pool
    event LiquidityAdded(address indexed provider, address indexed token0, address indexed token1, uint256 amount);

    /// @notice Emit when liquidity threshold is reached
    event LiquidityThresholdReached(address indexed token0, address indexed token1);

    ////////////////
    // Functions //
    //////////////
    /**
     * @param _poolManager Address of the Uniswap V4 PoolManager contract.
     * @param _vestingContract Address of the VestingContract for managing liquidity provider vesting schedules.
     */
    constructor(address _poolManager, address _vestingContract) {
        poolManager = IPoolManager(_poolManager);
        vestingContract = VestingContract(_vestingContract);
    }

    /**
     * @notice Initializes a new Uniswap V4 pool with specified parameters.
     * @param token0 The address of the first token in the pool.
     * @param token1 The address of the second token in the pool.
     * @param swapFee The fee to be used for swaps in the pool (e.g., 300 for 0.3%).
     * @param tickSpacing Spacing for ticks in the pool.
     * @param startingPrice Initial price for the pool, in Q64.96 format.
     * @dev This function can only be called once per token pair to prevent duplicate pool initialization.
     */
    function initializePool(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickSpacing,
        uint160 startingPrice
    )
        external
    {
        if (poolInitialized[token0]) {
            revert PoolAlreadyInitialized();
        }
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0)) // Hookless pool
         });

        poolManager.initialize(poolKey, startingPrice);
        poolInitialized[token0] = true;
        poolInitialized[token1] = true;
        emit PoolInitialized(token0, token1, address(poolManager));
    }

    /**
     * @notice Adds liquidity to an initialized Uniswap V4 pool.
     * @param token0 Address of the first token in the pool.
     * @param token1 Address of the second token in the pool.
     * @param swapFee The fee tier for the pool.
     * @param tickLower Lower bound for liquidity range.
     * @param tickUpper Upper bound for liquidity range.
     * @param amountToken0 Amount of `token0` to provide as liquidity.
     * @param amountToken1 Amount of `token1` to provide as liquidity.
     * @dev Once a user’s liquidity provision exceeds `liquidityThreshold`, a vesting schedule is set up for the
     * provider.
     */
    function addLiquidity(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountToken0,
        uint256 amountToken1
    )
        external
    {
        if (!poolInitialized[token0]) revert PoolNotInitialized();

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amountToken0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amountToken1);

        uint256 totalLiquidity = amountToken0 + amountToken1;
        liquidityProviders[msg.sender][token0].amountProvided += totalLiquidity;

        if (liquidityProviders[msg.sender][token0].amountProvided >= liquidityThreshold) {
            emit LiquidityThresholdReached(token0, token1);

            vestingContract.setVestingSchedule(msg.sender, token0, block.timestamp, 8 * 30 days, totalLiquidity);
            liquidityProviders[msg.sender][token0].hasVested = true;
        }

        emit LiquidityAdded(msg.sender, token0, token1, totalLiquidity);
    }

    /**
     * @notice Allows liquidity providers to claim their vested tokens once the vesting period is complete.
     * @dev Only claimable after the vesting period has expired, as per the vesting contract.
     */
    function claimVestedTokens() external {
        vestingContract.release(msg.sender);
    }

    /**
     * @notice Checks if a provider has met the liquidity threshold for a specific token.
     * @param token The token address to check the liquidity threshold for.
     * @return Boolean indicating if the liquidity threshold has been met for the provider.
     */
    function isThresholdMet(address token) external view returns (bool) {
        return liquidityProviders[msg.sender][token].amountProvided >= liquidityThreshold;
    }
}
