// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.26;

// import "../src/Router.sol";
// import {Script, console} from "forge-std/Script.sol";

// /// @notice Example script showing how to call approveToken on RouterOneInch
// contract S0006ApproveOneInch is Script {
//     function run() external {
//         // 用户私钥
//         uint256 userPrivateKey = 0x80da6e2d95afdaade210199fa2045461a2a7b1712b4536e2b3e60d9b562be664;
//         // RouterOneInch 合约地址
//         address routerAddress = vm.envAddress("S0002_ROUTER_ADDRESS");
//         // 需要授权的 token 地址
//         address token = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
//         // 授权额度
//         uint256 amount = 200000000000000000000000;

//         IRouter router = IRouter(routerAddress);

//         vm.startBroadcast(userPrivateKey);
//         router.approveToken(token, amount);
//         vm.stopBroadcast();

//         console.log("approveToken called: router=%s, token=%s, amount=%d", routerAddress, token, amount);
//     }
// }