// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {MultiSigContract} from "../../../src/MultiSigContract.sol";
import {FactoryTokenContract} from "../../../src/FactoryTokenContract.sol";
import {LiquidityManager} from "../../../src/LiquidityManager.sol";
import {TokenContract} from "../../../src/helpers/TokenContract.sol";

contract FactoryTokenContractTest is StdCheats, Test, Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    HelperConfig public hc;
    FactoryTokenContract public ftc;
    address public owner = address(1);
    address public notOwner = address(2);
    address[] public signers = new address[](2);
    uint256 public txId;

    function setUp() public {
        signers[0] = owner;
        signers[1] = notOwner;
        vm.startPrank(owner);
        hc = new HelperConfig();
        msc = new MultiSigContract();
        lm = new LiquidityManager(hc.getAnvilConfig().poolManager, address(0));
        ftc = new FactoryTokenContract(address(msc), address(lm), owner);
        msc.setFactoryTokenContract(address(ftc));
        txId = ftc.queueCreateMemecoin(
            signers,
            owner,
            "test",
            "test",
            100,
            100,
            false,
            false,
            false
        );
        msc.signTx(txId);
        vm.stopPrank();
        vm.prank(notOwner);
        msc.signTx(txId);
    }

    function testQueueTx() public view {
        assertGt(txId, 0);
        FactoryTokenContract.TxData memory txData = ftc.getTxData(txId);
        assertEq(txData.txId, txId);
        assertEq(txData.owner, owner);
        assertEq(txData.signers.length, 2);
        assertEq(txData.isPending, false);
    }

    function testExecuteCreateMemecoin() public view {
        FactoryTokenContract.TxData memory txData = ftc.getTxData(txId);
        assertEq(TokenContract(txData.tokenAddress).owner(), owner);
    }
}
