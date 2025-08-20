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

contract FactoryTokenContractV2 is Ownable, ReentrancyGuard, Pausable {}
