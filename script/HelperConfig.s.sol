//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {console2} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {PoolManagerMock} from "../test/unit/anvil/Mocks/PoolManagerMock.sol";
import {ISPMock} from "../test/unit/anvil/Mocks/ISPMock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address poolManager;
        address ispAddress;
        uint64 signatureSchemaId;
    }

    NetworkConfig public ActiveConfig;

    constructor() {}

    function getOptimismMainnetConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        console2.log("Working on optimism mainnet now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(2),
            ispAddress: address(0),
            signatureSchemaId: 1
        });
        return config;
    }

    function getOptimismSepoliaConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        console2.log("Working on optimism sepolia now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(2),
            ispAddress: address(0),
            signatureSchemaId: 1
        });
        return config;
    }

    function getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        console2.log("Working on base sepolia now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829,
            ispAddress: 0x4e4af2a21ebf62850fD99Eb6253E1eFBb56098cD,
            signatureSchemaId: 961
        });
        return config;
    }

    function getETHSepoliaConfig() public view returns (NetworkConfig memory) {
        console2.log("Working on base sepolia now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A,
            ispAddress: 0x878c92FD89d8E0B93Dc0a3c907A2adc7577e39c5,
            signatureSchemaId: 694
        });
        return config;
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        PoolManagerMock poolMock = new PoolManagerMock();
        ISPMock ispMock = new ISPMock();
        console2.log("Wotking on optimism mainnet now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(poolMock),
            ispAddress: address(ispMock),
            signatureSchemaId: 1
        });
        return config;
    }

    function getActiveConfig() public view returns (NetworkConfig memory) {
        return ActiveConfig;
    }
}
