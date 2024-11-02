// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {MultiSigContract} from "../../src/MultiSigContract.sol";
import {FactoryTokenContract} from "../../src/FactoryTokenContract.sol";
import {LiquidityManager} from "../../src/LiquidityManager.sol";
import {VestingContract} from "../../src/VestingContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployAndTest is Script {
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
            hc.getBaseSepoliaConfig().ispAddress,
            hc.getBaseSepoliaConfig().signatureSchemaId
        );
        console2.log("MultiSigContract deployed at:", address(msc));

        // Step 2: Deploy VestingContract
        vc = new VestingContract(msg.sender);
        console2.log("VestingContract deployed at:", address(vc));

        // Step 3: Deploy LiquidityManager
        lm = new LiquidityManager(
            hc.getBaseSepoliaConfig().poolManager,
            address(vc)
        );
        console2.log("LiquidityManager deployed at:", address(lm));

        // Step 4: Deploy FactoryTokenContract and set in MultiSigContract
        ftc = new FactoryTokenContract(
            address(msc),
            address(lm),
            hc.getBaseSepoliaConfig().USDC,
            msg.sender
        );
        console2.log("FactoryTokenContract deployed at:", address(ftc));
        msc.setFactoryTokenContract(address(ftc));

        // Step 5: Queue a new token creation
        address[] memory signers = new address[](2);
        signers[0] = address(0xb0EFd2b19A5698a9c830548aC22708a28c9d4552); // Replace with actual signer address
        signers[1] = address(0xfe63Ba8189215E5C975e73643b96066B6aD41A45); // Replace with actual signer address

        uint256 txId = ftc.queueCreateMemecoin(
            signers,
            msg.sender,
            "TestToken",
            "TTKN",
            1_000_000 * 1e18,
            2_000_000 * 1e18,
            true, // canMint
            true, // canBurn
            true, // supplyCapEnabled
            ""
        );
        console2.log("Queued token creation with txId:", txId);

        // Step 6: Sign the queued transaction
        msc.signTx(txId);
        console2.log("First signer approved transaction");
        vm.stopBroadcast();

        vm.startBroadcast(signers[1]);
        msc.signTx(txId);
        console2.log("Second signer approved transaction - token created");
        vm.stopBroadcast();

        vm.startBroadcast();
        // Step 7: Add liquidity for the token, Check if liquidity threshold met, Apply vesting for liquidity providers
        address tokenAddress = ftc.getTxData(txId).tokenAddress;
        address stableCoinAddress = address(
            0x036CbD53842c5426634e7929541eC2318f3dCF7e
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
