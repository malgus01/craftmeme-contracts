// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { Test, console2 } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { MultiSigContract } from "../../../src/MultiSigContract.sol";
import { FactoryTokenContract } from "../../../src/FactoryTokenContract.sol";
import { LiquidityManager } from "../../../src/LiquidityManager.sol";

contract CollateralSafekeepTest is StdCheats, Test, Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    HelperConfig public hc;
    FactoryTokenContract public ftc;
    address public owner = address(1);

    function setUp() public {
        vm.startPrank(owner);
        hc = new HelperConfig();
        msc = new MultiSigContract(hc.getBaseSepoliaConfig().ispAddress, hc.getBaseSepoliaConfig().signatureSchemaId);
        ftc = new FactoryTokenContract(address(msc), address(lm), hc.getAnvilConfig().USDC, owner);
        msc.setFactoryTokenContract(address(ftc));
        vm.stopPrank();
    }
}
