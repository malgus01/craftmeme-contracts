// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {MultiSigContract} from "../../../src/MultiSigContract.sol";
import {FactoryTokenContract} from "../../../src/FactoryTokenContract.sol";
import {LiquidityManager} from "../../../src/LiquidityManager.sol";

contract MultiSigContractTest is StdCheats, Test, Script {
    MultiSigContract public msc;
    LiquidityManager public lm;
    HelperConfig public hc;
    FactoryTokenContract public ftc;
    address public owner = address(1);
    address public notOwner = address(2);
    uint256 public txId;

    function setUp() public {
        vm.startPrank(owner);
        hc = new HelperConfig();
        msc = new MultiSigContract();
        lm = new LiquidityManager(
            address(hc.getAnvilConfig().poolManager),
            address(0)
        );
        ftc = new FactoryTokenContract(address(msc), address(lm), owner);

        msc.setFactoryTokenContract(address(ftc));

        address[] memory signers = new address[](2);
        signers[0] = owner;
        signers[1] = notOwner;
        txId = ftc.queueCreateMemecoin(
            signers,
            owner,
            "Memecoin",
            "MEM",
            1_000_000,
            1_000_000,
            true,
            true,
            true
        );
        vm.stopPrank();
    }

    function testQueueTx() public {
        address[] memory signers = new address[](2);
        signers[0] = owner;
        signers[1] = notOwner;
        vm.prank(owner);
        msc.queueTx(3, owner, signers);
        MultiSigContract.TxData memory txn = msc.getPendingTxData(3);
        assertEq(txn.txId, 3);
    }

    function testSignTx() public {
        vm.prank(notOwner);
        msc.signTx(txId);
        MultiSigContract.TxData memory txn = msc.getPendingTxData(txId);
        address[] memory signatures = txn.signatures;
        assertEq(signatures.length, 1);
        address temp;
        for (uint256 i = 0; i < signatures.length; i++) {
            if (signatures[i] == notOwner) {
                temp = signatures[i];
            }
        }
        assertEq(temp, notOwner);
    }

    function testUnsignTx() public {
        vm.startPrank(notOwner);
        msc.signTx(txId);
        msc.unsignTx(txId);
        MultiSigContract.TxData memory txn = msc.getPendingTxData(txId);
        address[] memory signatures = txn.signatures;
        for (uint256 i = 0; i < signatures.length; i++) {
            assertNotEq(signatures[i], notOwner);
        }
        vm.stopPrank();
    }

    function testExecuteTx() public {
        vm.prank(owner);
        msc.signTx(txId);
        vm.prank(notOwner);
        msc.signTx(txId);
        MultiSigContract.TxData memory txn = msc.getPendingTxData(txId);
        assertEq(txn.signers.length, 0);
        assertEq(txn.signatures.length, 0);
        assertEq(txn.txId, 0);
        assertEq(txn.owner, address(0));
    }
}
