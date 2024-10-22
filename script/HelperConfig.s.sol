//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

/**
 * uint256 _CIP,
 *         uint256 _baseRiskRate,
 *         uint256 _riskPremiumRate,
 *         address _indai,
 *         address _priceContract
 */
contract HelperConfig is Script {
    uint256 BASE_RISK_RATE = 150;
    uint256 RISK_PREMIUM_RATE = 130;
    uint256 CIP = 150;

    struct NetworkConfig {
        address priceFeed;
        address priceFeed2;
        uint256 cip;
        uint256 baseRiskRate;
        uint256 riskPremiumRate;
    }

    NetworkConfig public ActiveConfig;

    constructor() {}

    function getOptimismMainnetConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        console.log("Wotking on optimism mainnet now....");
        NetworkConfig memory mainnetConfig = NetworkConfig({
            priceFeed: vm.envAddress(
                "OPTIMISM_MAINNET_INRUSD_PRICEFEED_ADDRESS"
            ),
            priceFeed2: vm.envAddress(
                "OPTIMISM_MAINNET_ETHUSD_PRICEFEED_ADDRESS"
            ),
            baseRiskRate: BASE_RISK_RATE,
            riskPremiumRate: RISK_PREMIUM_RATE,
            cip: CIP
        });
        return mainnetConfig;
    }

    function getOptimismSepoliaConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        console.log("Working on optimism sepolia now....");
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: address(0),
            priceFeed2: vm.envAddress(
                "OPTIMISM_SEPOLIA_ETHUSD_PRICEFEED_ADDRESS"
            ),
            baseRiskRate: BASE_RISK_RATE,
            riskPremiumRate: RISK_PREMIUM_RATE,
            cip: CIP
        });
        return sepoliaConfig;
    }

    function getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        console.log("Working on base sepolia now....");
        NetworkConfig memory baseConfig = NetworkConfig({
            priceFeed: address(0),
            priceFeed2: vm.envAddress("BASE_SEPOLIA_ETHUSD_PRICEFEED_ADDRESS"),
            baseRiskRate: BASE_RISK_RATE,
            riskPremiumRate: RISK_PREMIUM_RATE,
            cip: CIP
        });
        return baseConfig;
    }

    // function getAnvilConfig() public returns (NetworkConfig memory) {
    //     console.log("local network detected, deploying mocks!!");
    //     MockV3Aggregator mock = new MockV3Aggregator(uint8(8), int256(1200000));
    //     MockV3Aggregator mock2 = new MockV3Aggregator(
    //         uint8(8),
    //         int256(325834000000)
    //     );
    //     NetworkConfig memory anvilConfig = NetworkConfig({
    //         priceFeed: address(mock),
    //         priceFeed2: address(mock2),
    //         baseRiskRate: BASE_RISK_RATE,
    //         riskPremiumRate: RISK_PREMIUM_RATE,
    //         cip: CIP
    //     });
    //     return anvilConfig;
    // }

    function getActiveConfig() public view returns (NetworkConfig memory) {
        return ActiveConfig;
    }
}
