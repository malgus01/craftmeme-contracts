// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { IHooks } from "v4-core/src/interfaces/IHooks.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { CurrencyLibrary, Currency } from "v4-core/src/types/Currency.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VestingContract } from "./VestingContract.sol";

contract LiquidityManager {
    error PoolAlreadyInitialized();
    error PoolNotInitialized();

    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    IPoolManager public poolManager;
    VestingContract public vestingContract;
    uint256 public liquidityThreshold = 20 * 1e6; // 20 USDT or USDC

    struct LiquidityProvider {
        uint256 amountProvided;
        bool hasVested;
    }

    event PoolInitialized(address indexed token0, address indexed token1, address indexed pool);
    event LiquidityAdded(address indexed provider, address indexed token0, address indexed token1, uint256 amount);
    event LiquidityThresholdReached(address indexed token0, address indexed token1);

    // Mapping of liquidity providers to tokens they provided liquidity for
    mapping(address => mapping(address => LiquidityProvider)) public liquidityProviders;
    mapping(address => bool) public poolInitialized;

    constructor(IPoolManager _poolManager, VestingContract _vestingContract) {
        poolManager = _poolManager;
        vestingContract = _vestingContract;
    }

    // Initialize a Uniswap V4 pool if it hasn't been initialized yet
    function initializePool(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickSpacing,
        uint160 startingPrice
    )
        external
    {
        require(!poolInitialized[token0], PoolAlreadyInitialized());
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
        emit PoolInitialized(token0, token1, address(poolManager));
    }

    // Add liquidity to a Uniswap V4 pool
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
        require(poolInitialized[token0], PoolNotInitialized());

        // Transfer tokens from the provider to the contract
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amountToken0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amountToken1);

        // Logic for checking the liquidity threshold
        uint256 totalLiquidity = amountToken0 + amountToken1;
        liquidityProviders[msg.sender][token0].amountProvided += totalLiquidity;

        // Once threshold is reached, trading is enabled on Uniswap
        if (liquidityProviders[msg.sender][token0].amountProvided >= liquidityThreshold) {
            emit LiquidityThresholdReached(token0, token1);

            // Lock liquidity provider's tokens in the VestingContract
            vestingContract.setVestingSchedule(
                msg.sender,
                block.timestamp,
                8 * 30 days, // 8 months vesting period
                totalLiquidity
            );
            liquidityProviders[msg.sender][token0].hasVested = true;
        }

        emit LiquidityAdded(msg.sender, token0, token1, totalLiquidity);
    }

    // Allow users to claim their vested tokens
    function claimVestedTokens() external {
        vestingContract.release(msg.sender);
    }
}
