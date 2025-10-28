// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import "../src/Router.sol";

contract S0001DeployRouter is Script {
    enum ChainName {
        Unknown,
        Eth,
        Mantle,
        Arbi,
        Sepolia,
        Bsc
    }

    mapping(string => ChainName) private chainNames;

    constructor() {
        chainNames["Eth"] = ChainName.Eth;
        chainNames["Mantle"] = ChainName.Mantle;
        chainNames["Arbi"] = ChainName.Arbi;
        chainNames["Sepolia"] = ChainName.Sepolia;
        chainNames["Bsc"] = ChainName.Bsc;
    }

    function run() external {
        uint256 adminPrivateKey = vm.envUint("S0001_ADMIN_PRIVATE_KEY");
        string memory chain = vm.envString("CHAIN");
        address adminAddress = vm.addr(adminPrivateKey);
        ChainName chainName = chainNames[chain];
        address wrappedNativeAddress;
        address v2Router;
        address v3Router;
        address oneInchRouter;
        uint256 initialFeeRate;
        address initialFeeCollector;
        address usdtAddress;
        address nativePlaceholder = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        if (chainName == ChainName.Arbi) {
            v2Router = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
            v3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
            wrappedNativeAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
            usdtAddress = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
            oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;
            initialFeeRate = 30; // 0.3%
            initialFeeCollector = adminAddress;
        } else if (chainName == ChainName.Sepolia) {
            v2Router = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
            v3Router = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
            wrappedNativeAddress = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
            usdtAddress = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
            oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;
            initialFeeRate = 30; // 0.3%
            initialFeeCollector = adminAddress;
        } else if (chainName == ChainName.Eth) {
            v2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            v3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
            wrappedNativeAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;
            initialFeeRate = 30; // 0.3%
            initialFeeCollector = adminAddress;
        } else if (chainName == ChainName.Bsc) {
            v2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
            v3Router = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
            wrappedNativeAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            usdtAddress = 0x55d398326f99059fF775485246999027B3197955;
            oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;
            initialFeeRate = 30; // 0.3%
            initialFeeCollector = adminAddress;
        }

        if (wrappedNativeAddress == address(0)) {
            revert(string(abi.encodePacked("Invalid chain: ", chain)));
        }

        vm.startBroadcast(adminPrivateKey);
        Router router = new Router(
            adminAddress,
            v2Router,
            v3Router,
            oneInchRouter,
            wrappedNativeAddress,
            usdtAddress,
            nativePlaceholder,
            initialFeeRate
        );
        vm.stopBroadcast();
        console.log("Chain: %s, Router: %s", chain, address(router));
    }
}
