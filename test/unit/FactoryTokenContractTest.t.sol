// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { Test, console2 } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { MultiSigContract } from "../../../src/MultiSigContract.sol";
import { FactoryTokenContract } from "../../../src/FactoryTokenContract.sol";
import { LiquidityManager } from "../../../src/LiquidityManager.sol";

contract FactoryTokenContractTest is StdCheats, Test, Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    HelperConfig public hc;
    FactoryTokenContract public ftc;
    address public owner = address(1);
    address public signer = address(2);
    address public signer2 = address(3);

    function setUp() public {
        vm.startPrank(owner);
        hc = new HelperConfig();
        msc = new MultiSigContract();
        ftc = new FactoryTokenContract(address(msc), address(lm), owner);
        msc.setFactoryTokenContract(address(ftc));
        vm.stopPrank();
    }

    function testQueueTx() public {
        address[] memory signers = new address[](3);
        signers[0] = owner;
        signers[1] = signer;
        signers[2] = signer2;
        vm.prank(owner);
        uint256 txId = ftc.queueCreateMemecoin(signers, owner, "test", "test", 100, 100, false, false, false);
        assertGt(txId, 0);
        ftc.getTxData(txId);
    }
}
