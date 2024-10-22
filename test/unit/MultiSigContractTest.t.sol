// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {MultiSigContract} from "../../../src/MultiSigContract.sol";
import {FactoryTokenContract} from "../../../src/FactoryTokenContract.sol";

contract MultiSigContractTest is StdCheats, Test, Script {
    MultiSigContract public msc;
    HelperConfig public hc;
    FactoryTokenContract public ftc;
    address public owner = address(1);
    address public notOwner = address(2);

    function setUp() public {
        vm.startPrank(owner);
        hc = new HelperConfig();
        msc = new MultiSigContract();
        ftc = new FactoryTokenContract(address(msc), owner);
        msc.setFactoryTokenContract(address(ftc));
        vm.stopPrank();
    }

    function testQueueTx() public {
        address[] memory signers = new address[](2);
        signers[0] = address(2);
        signers[1] = address(3);
        vm.prank(owner);
        msc.queueTx(3, owner, signers);
        msc.getPendingTxData(3);
    }

    function testSignTx() public {}
}
