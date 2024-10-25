// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @notice Interface for the PoolManager
contract PoolManagerMock {
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick) { }
}
