//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {console2} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {PoolManagerMock} from "../test/unit/anvil/Mocks/PoolManagerMock.sol";

contract HelperConfig is Script {
    PoolManagerMock mock = new PoolManagerMock();
    struct NetworkConfig {
        address poolManager;
    }

    NetworkConfig public ActiveConfig;

    constructor() {}

    function getOptimismMainnetConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        console2.log("Wotking on optimism mainnet now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(mock)
        });
        return config;
    }

    function getOptimismSepoliaConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        console2.log("Wotking on optimism mainnet now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(mock)
        });
        return config;
    }

    function getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        console2.log("Wotking on optimism mainnet now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(mock)
        });
        return config;
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        console2.log("Wotking on optimism mainnet now....");
        NetworkConfig memory config = NetworkConfig({
            poolManager: address(mock)
        });
        return config;
    }

    function getActiveConfig() public view returns (NetworkConfig memory) {
        return ActiveConfig;
    }
}
