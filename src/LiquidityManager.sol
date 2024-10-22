// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquidityManager is Ownable {
    ERC20 private immutable memeToken;
    address private immutable WETH;

    constructor(address initialOwner, address _memeToken) Ownable(initialOwner) {
        memeToken = ERC20(_memeToken);
    }

    function addLiquidity() external { }

    function swapETHForTokens() external { }

    function swapTokensForETH() external { }
}
