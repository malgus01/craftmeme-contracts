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
