// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {console2} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {MultiSigContract} from "../../../src/MultiSigContract.sol";
import {FactoryTokenContract} from "../../../src/FactoryTokenContract.sol";
import {LiquidityManager} from "../../../src/LiquidityManager.sol";
import {VestingContract} from "../../../src/VestingContract.sol";

contract DeployAndSetup is Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    FactoryTokenContract public ftc;
    VestingContract public vc;
    HelperConfig public hc;

    function run() public {
        hc = new HelperConfig();
        vm.startBroadcast();
        // Step 1: Deploy MultiSigContract
        msc = new MultiSigContract(
            hc.getETHSepoliaConfig().ispAddress,
            hc.getETHSepoliaConfig().signatureSchemaId
        );
        console2.log("MultiSigContract deployed at:", address(msc));

        // Step 2: Deploy VestingContract
        vc = new VestingContract(msg.sender);
        console2.log("VestingContract deployed at:", address(vc));

        // Step 3: Deploy LiquidityManager
        lm = new LiquidityManager(
            hc.getETHSepoliaConfig().poolManager,
            address(vc)
        );
        console2.log("LiquidityManager deployed at:", address(lm));

        // Step 4: Deploy FactoryTokenContract and set in MultiSigContract
        ftc = new FactoryTokenContract(
            address(msc),
            address(lm),
            hc.getETHSepoliaConfig().USDC,
            msg.sender
        );
        console2.log("FactoryTokenContract deployed at:", address(ftc));
        msc.setFactoryTokenContract(address(ftc));
        vm.stopBroadcast();
    }
}
