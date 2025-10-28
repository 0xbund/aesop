// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/interfaces/IRouterAccessControl.sol";
import {RouterAccessControl} from "../src/RouterAccessControl.sol";
import {Script, console} from "forge-std/Script.sol";

contract S0003AcceptAdminTransfer is Script {
    function run() external {
        uint256 newAdminPrivateKey = vm.envUint("S0003_NEW_ADMIN_PRIVATE_KEY");
        string memory chain = vm.envString("CHAIN");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");
        IRouterAccessControl router = IRouterAccessControl(routerAddress);
        vm.startBroadcast(newAdminPrivateKey);
        router.acceptAdminTransfer();
        vm.stopBroadcast();
        console.log("Admin transfer accepted, Chain: %s, Router: %s", chain, routerAddress);
    }
}
