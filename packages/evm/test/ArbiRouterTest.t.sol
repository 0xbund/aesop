// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Router.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract ArbiRouterTest is Test {
    using Math for uint256;

    Router public router;
    Account internal admin;
    Account internal newAdmin;
    Account internal trader;
    address public v2Router;
    address public v3Router;
    address public oneInchRouter;
    uint256 public initialFeeRate;
    address public NATIVE_PLACEHOLDER;
    uint256 constant FEE_DENOMINATOR = 1e4;

    address private constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function setUp() public {
        admin = makeAccount("admin");
        newAdmin = makeAccount("newAdmin");
        trader = makeAccount("trader");
        deal(trader.addr, 1 << 128);
        deal(usdc, trader.addr, 1e10);

        v2Router = address(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24); 
        v3Router = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        oneInchRouter = address(0x111111125421cA6dc452d289314280a0f8842A65);
        NATIVE_PLACEHOLDER = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        initialFeeRate = 30; // 0.3%

        router = new Router(
            admin.addr,
            v2Router,
            v3Router,
            oneInchRouter,
            weth,
            usdc,
            NATIVE_PLACEHOLDER,
            initialFeeRate
        );
    }

    function testUpdateFeeRate() public {
        vm.startBroadcast(admin.key);
        uint256 newFeeRate = 50; // 0.5%
        router.updateFeeRate(newFeeRate);
        vm.stopBroadcast();
        assertEq(router.feeRate(), newFeeRate, "Fee rate should be updated");
    }

    function testGrantRole() public {
        vm.startBroadcast(admin.key);
        router.grantRole(keccak256("ADMIN"), trader.addr);
        vm.stopBroadcast();
    }

    function testOnlyV3SwapExactInWETHToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05%
        
        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));

        vm.startBroadcast(trader.key);
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 10 ** 18,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        (, uint256 v3AmountOut) = router.swapExactIn{value: params.amountIn}(params, 0);
        vm.stopBroadcast();

        uint256 balanceUsdcAfter = IERC20(usdc).balanceOf(address(trader.addr));

        assertEq(balanceUsdcAfter - balanceUsdcBefore, v3AmountOut, "should get v3AmountOut");
        assertEq(IERC20(path[0]).balanceOf(address(router)), params.amountIn * initialFeeRate / 10000, "router balance should get fee");
    }

    function testOnlyV2SwapExactInWETHToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);

        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));

        vm.startBroadcast(trader.key);
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 10000000000000000,
            v2AmountRatio: 10000,
            v3AmountRatio: 0,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        (uint256 v2AmountOut, ) = router.swapExactIn{value: params.amountIn}(params, 0);
        vm.stopBroadcast();

        uint256 balanceUsdcAfter = IERC20(usdc).balanceOf(address(trader.addr));

        assertEq(IERC20(path[0]).balanceOf(address(router)), 30000000000000, "router balance should be 30000000000000");
        assertEq(balanceUsdcAfter - balanceUsdcBefore, v2AmountOut, "balance of usdc should be 11464510");
    }

    function testOnlyV2SwapExactOutWETHToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;
        uint24[] memory fees = new uint24[](1);

        vm.startBroadcast(trader.key);

        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));
        uint256 balanceWethBefore = IERC20(weth).balanceOf(address(router));

        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 10000000000000000,
            v3AmountInMax: 0,
            v2AmountRatio: 10000,
            v3AmountRatio: 0,
            amountOut: 10445250,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        (uint256 v2AmountIn, ) = router.swapExactOut{value: params.v2AmountInMax + params.v3AmountInMax}(params, 0);
        vm.stopBroadcast();

        uint256 balanceUsdcAfter = IERC20(usdc).balanceOf(address(trader.addr));
        uint256 balanceWethAfter = IERC20(weth).balanceOf(address(router));

        assertEq(balanceUsdcAfter - balanceUsdcBefore, params.amountOut, "balance of usdc should be 10445250");
        assertEq(balanceWethAfter - balanceWethBefore, v2AmountIn * initialFeeRate / 10000, "router balance should get fee");
    }

    function testOnlyV3SwapExactOutWETHToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;
        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05%

        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));
        vm.startBroadcast(trader.key);
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: 10000000000000000,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: 10000000,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        (, uint256 v3AmountIn) = router.swapExactOut{value: params.v2AmountInMax + params.v3AmountInMax}(params, 0);
        vm.stopBroadcast();

        uint256 balanceUsdcAfter = IERC20(usdc).balanceOf(address(trader.addr));

        assertEq(balanceUsdcAfter - balanceUsdcBefore, params.amountOut, "trader balance should be 10000000");     
        assertEq(IERC20(path[0]).balanceOf(address(router)), v3AmountIn * initialFeeRate / 10000, "router balance should get fee");
    }

    function testAdminTransfer() public {
        vm.startBroadcast(admin.key);
        router.initiateAdminTransfer(newAdmin.addr);
        vm.stopBroadcast();

        vm.startBroadcast(newAdmin.key);
        router.acceptAdminTransfer();
        vm.stopBroadcast();
    }

    function testOnlyV3SwapExactInUSDCToWETH() public {
        // Setup USDC -> WETH path
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05%
        
        vm.startBroadcast(trader.key);
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);

        uint256 balanceWethBefore = IERC20(weth).balanceOf(address(trader.addr));
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1000000, // 1 USDC
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        (, uint256 v3AmountOut) = router.swapExactIn(params, 0);
        vm.stopBroadcast();

        uint256 balanceWethAfter = IERC20(weth).balanceOf(address(trader.addr));

        assertEq(IERC20(path[path.length-1]).balanceOf(address(router)), v3AmountOut * initialFeeRate / 10000, "router balance should get fee");
        assertEq(balanceWethAfter - balanceWethBefore, v3AmountOut - v3AmountOut * initialFeeRate / 10000, "trader should receive WETH");
    }

    function testOnlyV2SwapExactInUSDCToWETH() public {
        // Setup USDC -> WETH path
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        
        vm.startBroadcast(trader.key);
        
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1000000, // 1 USDC
            v2AmountRatio: 10000,
            v3AmountRatio: 0,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        
        (uint256 v2AmountOut, ) = router.swapExactIn(params, 0);
        vm.stopBroadcast();

        assertEq(IERC20(path[path.length-1]).balanceOf(address(router)), v2AmountOut * initialFeeRate / 10000, "router balance should be 1000000 * 0.3% = 3000");
        assertEq(IERC20(path[path.length-1]).balanceOf(trader.addr), v2AmountOut - v2AmountOut * initialFeeRate / 10000, "trader should receive WETH");
    }

    function testOnlyV2SwapExactOutUSDCToWETH() public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        
        vm.startBroadcast(trader.key);
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);

        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 2000000, // 2 USDC max input
            v3AmountInMax: 0,
            v2AmountRatio: 10000,
            v3AmountRatio: 0,
            amountOut: 380000000000000, // Expected WETH output
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactOut(params, 0);
        vm.stopBroadcast();

        assertEq(IERC20(path[path.length-1]).balanceOf(trader.addr), params.amountOut, "trader should receive exact WETH amount");
        assertEq(IERC20(path[path.length-1]).balanceOf(address(router)), params.amountOut * initialFeeRate / 10000, "router should receive correct fee");
    }

    function testOnlyV3SwapExactOutUSDCToWETH() public {
        // Setup USDC -> WETH path
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05%
        
        vm.startBroadcast(trader.key);
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);
        
        uint256 desiredOutput = 380000000000000; // 0.00038 WETH
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: 20000000, // 2 USDC max input
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: desiredOutput,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactOut(params, 0);
        vm.stopBroadcast();

        assertEq(IERC20(path[path.length-1]).balanceOf(trader.addr), desiredOutput, "trader should receive exact WETH amount");
        assertEq(IERC20(path[path.length-1]).balanceOf(address(router)), desiredOutput * initialFeeRate / 10000, "router should receive correct fee");
    }

    function testWithdrawToken() public {
        // First do a swap to get some tokens in the router
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;
        
        vm.startBroadcast(trader.key);
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 10 ** 18,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: params.amountIn}(params, 0);
        vm.stopBroadcast();

        // Get router's WETH balance
        uint256 routerBalance = IERC20(weth).balanceOf(address(router));
        assertGt(routerBalance, 0, "Router should have WETH balance");

        // Test withdrawToken
        address recipient = makeAccount("recipient").addr;
        vm.startBroadcast(admin.key);
        router.withdrawToken(weth, routerBalance, recipient);
        vm.stopBroadcast();

        assertEq(IERC20(weth).balanceOf(recipient), routerBalance, "Recipient should receive all WETH");
        assertEq(IERC20(weth).balanceOf(address(router)), 0, "Router should have 0 WETH");
    }

    function testApprove() public {
        vm.startBroadcast(admin.key);
        uint256 approveAmount = 1000000;
        router.approve(v2Router, usdc, approveAmount);
        vm.stopBroadcast();

        assertEq(
            IERC20(usdc).allowance(address(router), v2Router),
            approveAmount,
            "Allowance should be set correctly"
        );
    }

    function testWithdrawNativeToken() public {
        // First send some ETH to router
        vm.deal(address(router), 1 ether);
        
        address recipient = makeAccount("recipient").addr;
        uint256 withdrawAmount = 0.5 ether;
        
        uint256 recipientBalanceBefore = recipient.balance;
        
        vm.startBroadcast(admin.key);
        router.withdrawNativeToken(withdrawAmount, recipient);
        vm.stopBroadcast();

        assertEq(
            recipient.balance - recipientBalanceBefore,
            withdrawAmount,
            "Recipient should receive correct amount of ETH"
        );
    }

    function testErrorCases() public {
        // Test FeeRateTooHigh error
        vm.startBroadcast(admin.key);
        vm.expectRevert(Errors.FeeRateTooHigh.selector);
        router.updateFeeRate(FEE_DENOMINATOR / 10 + 1);
        vm.stopBroadcast();

        // Test InsufficientToken error for withdrawToken
        vm.startBroadcast(admin.key);
        vm.expectRevert(Errors.InsufficientToken.selector);
        router.withdrawToken(weth, 1 ether, admin.addr);
        vm.stopBroadcast();

        // Test InsufficientToken error for withdrawNativeToken
        vm.startBroadcast(admin.key);
        vm.expectRevert(Errors.InsufficientToken.selector);
        router.withdrawNativeToken(1 ether, admin.addr);
        vm.stopBroadcast();

        // Test InvalidPath error
        address[] memory path = new address[](1);
        path[0] = weth;
        uint24[] memory fees = new uint24[](0);

        vm.startBroadcast(trader.key);
        vm.expectRevert(Errors.InvalidPath.selector);
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 5000,
            v3AmountRatio: 5000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 1 ether}(params, 0);
        vm.stopBroadcast();

        // Test InvalidRatio error
        path = new address[](2);
        path[0] = weth;
        path[1] = usdc;
        fees = new uint24[](1);
        fees[0] = 500;

        vm.startBroadcast(trader.key);
        vm.expectRevert(Errors.InvalidRatio.selector);
        params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 5000,
            v3AmountRatio: 4000, // Total ratio != 10000
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 1 ether}(params, 0);
        vm.stopBroadcast();

        // Test InvalidEthAmount error
        vm.startBroadcast(trader.key);
        vm.expectRevert(Errors.InvalidNativeTokenAmount.selector);
        params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 5000,
            v3AmountRatio: 5000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 2 ether}(params, 0); // Sending more ETH than amountIn
        vm.stopBroadcast();

        // Test InvalidInputToken error
        path[0] = usdc; // Starting with USDC instead of WETH
        vm.startBroadcast(trader.key);
        vm.expectRevert(Errors.InvalidInputToken.selector);
        params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 5000,
            v3AmountRatio: 5000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 1 ether}(params, 0); // Trying to send ETH with non-WETH input
        vm.stopBroadcast();
    }

    function testEdgeCases() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;
        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        // Test with minimum possible amount
        vm.startBroadcast(trader.key);
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1, // Minimum amount
            v2AmountRatio: 5000,
            v3AmountRatio: 5000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 1}(params, 0);
        vm.stopBroadcast();

        // Test with maximum ratio for V2
        vm.startBroadcast(trader.key);
        params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 10000, // Maximum V2 ratio
            v3AmountRatio: 0,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 1 ether}(params, 0);
        vm.stopBroadcast();

        // Test with maximum ratio for V3
        vm.startBroadcast(trader.key);
        params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 0,
            v3AmountRatio: 10000, // Maximum V3 ratio
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactIn{value: 1 ether}(params, 0);
        vm.stopBroadcast();

        // Test with expired deadline
        vm.startBroadcast(trader.key);
        vm.expectRevert(); // Uniswap will revert with expired deadline
        params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: 1 ether,
            v2AmountRatio: 5000,
            v3AmountRatio: 5000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() - 1 // Past deadline
        });
        router.swapExactIn{value: 1 ether}(params, 0);
        vm.stopBroadcast();
    }

    function testAddSupportedToken() public {
        // Test adding USDC as supported token
        vm.startBroadcast(admin.key);
        router.addSupportedToken(usdc);
        vm.stopBroadcast();

        // Verify USDC is supported
        assertTrue(router.supportedTokens(usdc), "USDC should be supported");
    }

    function testRemoveSupportedToken() public {
        // First add USDC as supported token
        vm.startBroadcast(admin.key);
        router.addSupportedToken(usdc);
        vm.stopBroadcast();

        // Then remove it
        vm.startBroadcast(admin.key);
        router.removeSupportedToken(usdc);
        vm.stopBroadcast();

        // Verify USDC is no longer supported
        assertFalse(router.supportedTokens(usdc), "USDC should not be supported");
    }

    function testCannotRemoveWrappedToken() public {
        // Try to remove WETH (wrapped token)
        vm.startBroadcast(admin.key);
        vm.expectRevert(Errors.InvalidInputToken.selector);
        router.removeSupportedToken(weth);
        vm.stopBroadcast();

        // Verify WETH is still supported
        assertTrue(router.supportedTokens(weth), "WETH should still be supported");
    }

    function testOnlyAdminCanManageTokens() public {
        // Try to add token as non-admin
        vm.startBroadcast(trader.key);
        vm.expectRevert(IRouterAccessControl.OnlyAdmin.selector);
        router.addSupportedToken(usdc);
        vm.stopBroadcast();

        // Try to remove token as non-admin
        vm.startBroadcast(trader.key);
        vm.expectRevert(IRouterAccessControl.OnlyAdmin.selector);
        router.removeSupportedToken(usdc);
        vm.stopBroadcast();
    }

    function testIsTokenSupported() public {
        // Check WETH is supported by default
        assertTrue(router.isTokenSupported(weth), "WETH should be supported by default");
        
        // Check USDC is not supported by default
        assertFalse(router.isTokenSupported(usdc), "USDC should not be supported by default");
        
        // Add USDC support
        vm.startBroadcast(admin.key);
        router.addSupportedToken(usdc);
        vm.stopBroadcast();
        
        // Verify USDC is now supported
        assertTrue(router.isTokenSupported(usdc), "USDC should be supported after adding");
    }
}
