// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/interfaces/IRouterAccessControl.sol";
import {RouterAccessControl} from "../src/RouterAccessControl.sol";
import {Script, console} from "forge-std/Script.sol";

contract S0002InitiateAdminTransfer is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("S0001_ADMIN_PRIVATE_KEY");
        string memory chain = vm.envString("CHAIN");
        address routerAddress = vm.envAddress("S0002_ROUTER_ADDRESS");
        address account = vm.envAddress("S0002_NEW_ADMIN_ACCOUNT");
        IRouterAccessControl router = IRouterAccessControl(routerAddress);
        vm.startBroadcast(adminPrivateKey);
        router.initiateAdminTransfer(account);
        vm.stopBroadcast();
        console.log("Admin transfer initiated, Chain: %s, Router: %s, New Admin Account: %s", chain, routerAddress, account);
    }
}
