// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MultiSigContract} from "../../src/MultiSigContract.sol";
import {FactoryTokenContract} from "../../src/FactoryTokenContract.sol";
import {LiquidityManager} from "../../src/LiquidityManager.sol";
import {VestingContract} from "../../src/VestingContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AddLiquidity is Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    FactoryTokenContract public ftc;
    VestingContract public vc;
    HelperConfig public hc;

    function run() public {
        hc = new HelperConfig();
        vm.startBroadcast();
        ftc = FactoryTokenContract(0x301C96eC196fB6E1FE8B7eb777F317E5261B37eB);
        lm = LiquidityManager(0x86C82eFA601F306b7c5c16AE3B3f550714A6Bd8f);
        // Step 7: Add liquidity for the token, Check if liquidity threshold met, Apply vesting for liquidity providers
        address tokenAddress = ftc.getTxData(1).tokenAddress;
        address stableCoinAddress = address(
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        ); //Base Sepolia USDC
        uint256 liquidityAmount = 2 * 1e6; // 1 USDC/USDT
        IERC20(tokenAddress).approve(address(lm), liquidityAmount);
        lm.addLiquidity(
            tokenAddress,
            stableCoinAddress,
            300,
            -887_220,
            887_220,
            liquidityAmount,
            0
        );
        console2.log("Liquidity added for token at:", tokenAddress);

        // Step 8: Check if liquidity threshold met
        if (lm.isThresholdMet(tokenAddress)) {
            console2.log("Liquidity threshold met for token:", tokenAddress);
        }
        vm.stopBroadcast();
    }
}
