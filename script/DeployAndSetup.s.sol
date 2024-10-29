// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { console2 } from "forge-std/Test.sol";
import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { MultiSigContract } from "../../../src/MultiSigContract.sol";
import { FactoryTokenContract } from "../../../src/FactoryTokenContract.sol";
import { LiquidityManager } from "../../../src/LiquidityManager.sol";
import { VestingContract } from "../../../src/VestingContract.sol";

contract DeployAndSetup is Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    FactoryTokenContract public ftc;
    VestingContract public vc;
    HelperConfig public hc;

    function run() public {
        hc = new HelperConfig();
        vm.startBroadcast();
        msc = new MultiSigContract(hc.getBaseSepoliaConfig().ispAddress, hc.getBaseSepoliaConfig().signatureSchemaId);
        vc = new VestingContract(msg.sender);
        lm = new LiquidityManager(hc.getBaseSepoliaConfig().poolManager, address(vc));
        ftc = new FactoryTokenContract(address(msc), address(lm), msg.sender);
        msc.setFactoryTokenContract(address(ftc));
        vm.stopBroadcast();
    }
}
