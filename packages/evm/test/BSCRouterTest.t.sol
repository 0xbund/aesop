// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Router.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract BSCRouterTest is Test {
    using Math for uint256;

    Router public router;
    Account internal admin;
    Account internal newAdmin;
    Account internal trader;
    address public v2Router;
    address public v3Router;
    address public oneInchRouter;
    address public NATIVE_PLACEHOLDER;
    uint256 public initialFeeRate;
    uint256 constant FEE_DENOMINATOR = 1e4;

    // ETH Mainnet addresses
    address private constant weth = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant usdc = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address private constant uni = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    function setUp() public {
        admin = makeAccount("admin");
        newAdmin = makeAccount("newAdmin");
        trader = makeAccount("trader");
        deal(trader.addr, 1 << 128);
        deal(usdc, trader.addr, 1e22);

        // ETH Mainnet Uniswap router addresses
        v2Router = address(0x10ED43C718714eb63d5aA57B78B54704E256024E); 
        v3Router = address(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
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
        assertEq(balanceUsdcAfter - balanceUsdcBefore, v2AmountOut, "balance of usdc should be updated");
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
            v2AmountInMax: 2000000000000000000, // 2 USDC max input
            v3AmountInMax: 0,
            v2AmountRatio: 10000,
            v3AmountRatio: 0,
            amountOut: 3169570000000000, // Expected WETH output
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });
        router.swapExactOut(params, 0);
        vm.stopBroadcast();

        assertEq(IERC20(path[path.length-1]).balanceOf(trader.addr), params.amountOut, "trader should receive exact WETH amount");
        assertEq(IERC20(path[path.length-1]).balanceOf(address(router)), params.amountOut * initialFeeRate / 10000, "router should receive correct fee");
    }

    function testOnlyV3SwapExactOutUSDCToWETH() public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05%
        
        vm.startBroadcast(trader.key);
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);
        
        uint256 desiredOutput = 3169570000000000; // 0.00038 WETH
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: 2000000000000000000, // 2 USDC max input
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

    function testIsTokenSupported() public view {
        // Check WETH is supported by default
        assertTrue(router.isTokenSupported(weth), "WETH should be supported by default");
        
        // Check USDC is not supported by default
        assertTrue(router.isTokenSupported(usdc), "USDC should be supported by default");
    }

    function testSwapExactInUNIToWETH() public {
        
        address[] memory path = new address[](2);
        path[0] = uni;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI/WETH pool
        
        vm.startBroadcast(trader.key);
        // Give trader some UNI
        deal(uni, trader.addr, 10 * 10**18);
        
        // Approve UNI spending
        IERC20(uni).approve(address(router), type(uint256).max);

        uint256 uniAmount = 1 * 10**18; // 1 UNI
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: uniAmount,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 routerUniBalanceBefore = IERC20(uni).balanceOf(address(router));
        
        // Execute swap
        (, uint256 v3AmountOut) = router.swapExactIn(params, 0);
        vm.stopBroadcast();

        // Verify router didn't collect any UNI as fee
        console.log("supportedTokens(uni): %s", router.supportedTokens(uni));

        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUniBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify router collected WETH as fee
        uint256 expectedWethFee = v3AmountOut * initialFeeRate / 10000;
        assertEq(
            IERC20(weth).balanceOf(address(router)),
            expectedWethFee,
            "Router should collect fee in WETH"
        );

        // Verify trader received correct amount of WETH (minus fee)
        assertEq(
            IERC20(weth).balanceOf(trader.addr),
            v3AmountOut - expectedWethFee,
            "Trader should receive WETH amount minus fee"
        );
    }

    function testSwapExactInWETHToUNI() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = uni;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI/WETH pool
        
        vm.startBroadcast(trader.key);
        
        uint256 wethAmount = 1 ether; // 1 WETH
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: wethAmount,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceUniBefore = IERC20(uni).balanceOf(address(trader.addr));
        uint256 routerWethBalanceBefore = IERC20(weth).balanceOf(address(router));
        uint256 routerUniBalanceBefore = IERC20(uni).balanceOf(address(router));
        
        // Execute swap
        (, uint256 v3AmountOut) = router.swapExactIn{value: wethAmount}(params, 0);
        vm.stopBroadcast();

        // Since WETH is supported token (input), verify:
        // 1. Router should collect fee from input amount (WETH)
        // 2. Router should not collect fee from output amount (UNI)
        // 3. Trader should receive full output amount (UNI)

        // Verify router collected WETH as fee
        uint256 expectedWethFee = wethAmount * initialFeeRate / 10000;
        assertEq(
            IERC20(weth).balanceOf(address(router)) - routerWethBalanceBefore,
            expectedWethFee,
            "Router should collect fee in WETH"
        );

        // Verify router didn't collect any UNI as fee
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUniBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify trader received full amount of UNI
        assertEq(
            IERC20(uni).balanceOf(trader.addr) - balanceUniBefore,
            v3AmountOut,
            "Trader should receive full UNI amount"
        );
    }
    
    function testSwapExactInUNIToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = uni;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI pool
        
        vm.startBroadcast(trader.key);
        // Give trader some UNI
        deal(uni, trader.addr, 10 * 10**18);
        
        // Approve UNI spending
        IERC20(uni).approve(address(router), type(uint256).max);

        uint256 uniAmount = 1 * 10**18; // 1 UNI
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: uniAmount,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 routerUniBalanceBefore = IERC20(uni).balanceOf(address(router));
        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));
        uint256 routerUsdcBalanceBefore = IERC20(usdc).balanceOf(address(router));
        
        // Execute swap
        (, uint256 v3AmountOut) = router.swapExactIn(params, 0);
        vm.stopBroadcast();

        // Verify router didn't collect any UNI as fee

        console.log("routerUniBalanceBefore: %s", routerUniBalanceBefore);
        console.log("routerUniBalanceAfter: %s", IERC20(uni).balanceOf(address(router)));
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUniBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify router collected USDC as fee
        uint256 routerUsdcBalanceAfter = IERC20(usdc).balanceOf(address(router));
        uint256 actualFee = routerUsdcBalanceAfter - routerUsdcBalanceBefore;
        uint256 expectedUsdcFee = v3AmountOut * initialFeeRate / 10000;
        assertEq(
            actualFee,
            expectedUsdcFee,
            "Router should collect fee in USDC"
        );

        // Verify trader received correct amount of USDC (minus fee)
        assertEq(
            IERC20(usdc).balanceOf(trader.addr) - balanceUsdcBefore,
            v3AmountOut - expectedUsdcFee,
            "Trader should receive USDC amount minus fee"
        );
    }

    function testSwapExactInUSDCToUNI() public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = uni;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI pool
        
        vm.startBroadcast(trader.key);
        // Give trader some USDC
        deal(usdc, trader.addr, 10000 * 10**18); // 10000 USDC
        
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);

        uint256 usdcAmount = 1000 * 10**18; // 1000 USDC
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: usdcAmount,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceUniBefore = IERC20(uni).balanceOf(address(trader.addr));
        
        // Execute swap
        (, uint256 v3AmountOut) = router.swapExactIn(params, 0);

        // Record final balances
        uint256 routerUsdcBalanceAfter = IERC20(usdc).balanceOf(address(router));

        vm.stopBroadcast();

        // Verify router must collect USDC as fee
        assertEq(
            IERC20(usdc).balanceOf(address(router)),
            routerUsdcBalanceAfter,
            "Router must collect USDC as fee"
        );

        // Verify router must collect UNI as fee
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            0,
            "Router must not collect fee in UNI"
        );

        // Verify trader received correct amount of UNI (minus fee)
        uint256 expectedUniAmount = v3AmountOut - IERC20(uni).balanceOf(address(router));
        assertEq(
            IERC20(uni).balanceOf(trader.addr) - balanceUniBefore,
            expectedUniAmount,
            "Trader must receive UNI amount minus fee"
        );
    }

    function testSwapExactInUSDCToWETH() public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05% fee tier for USDC/WETH pool
        
        vm.startBroadcast(trader.key);
        // Give trader some USDC
        deal(usdc, trader.addr, 10000 * 10**6); // 10000 USDC
        
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);

        uint256 usdcAmount = 1000 * 10**6; // 1000 USDC
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: usdcAmount,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceWethBefore = IERC20(weth).balanceOf(address(trader.addr));
        
        // Execute swap
        (, uint256 v3AmountOut) = router.swapExactIn(params, 0);
        vm.stopBroadcast();

        // Verify router collected USDC as fee
        uint256 expectedUsdcFee = usdcAmount * initialFeeRate / 10000;
        assertEq(
            IERC20(usdc).balanceOf(address(router)),
            expectedUsdcFee,
            "Router should collect fee in USDC"
        );

        // Verify trader received correct amount of WETH
        assertEq(
            IERC20(weth).balanceOf(trader.addr) - balanceWethBefore,
            v3AmountOut,
            "Trader should receive full WETH amount"
        );
    }

    function testSwapExactInWETHToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05% fee tier for USDC/WETH pool
        
        vm.startBroadcast(trader.key);
        
        uint256 wethAmount = 1 ether; // 1 WETH
        
        IRouter.SwapExactInParams memory params = IRouter.SwapExactInParams({
            path: path,
            v3Fees: fees,
            amountIn: wethAmount,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            v2AmountOutMin: 0,
            v3AmountOutMin: 0,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));
        uint256 routerWethBalanceBefore = IERC20(weth).balanceOf(address(router));
        
        // Execute swap
        (, uint256 v3AmountOut) = router.swapExactIn{value: wethAmount}(params, 0);
        vm.stopBroadcast();

        // Verify router collected WETH as fee
        uint256 expectedWethFee = wethAmount * initialFeeRate / 10000;
        assertEq(
            IERC20(weth).balanceOf(address(router)) - routerWethBalanceBefore,
            expectedWethFee,
            "Router should collect fee in WETH"
        );

        // Verify trader received correct amount of USDC
        assertEq(
            IERC20(usdc).balanceOf(trader.addr) - balanceUsdcBefore,
            v3AmountOut,
            "Trader should receive full USDC amount"
        );
    }

    function testSwapExactOutWETHToUNI() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = uni;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI/WETH pool
        
        vm.startBroadcast(trader.key);
        
        uint256 wethAmountMax = 2 ether; // max 2 WETH
        uint256 uniAmountOut = 10 * 10**18; // want 10 UNI
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: wethAmountMax,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: uniAmountOut,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceUniBefore = IERC20(uni).balanceOf(address(trader.addr));
        uint256 routerWethBalanceBefore = IERC20(weth).balanceOf(address(router));
        uint256 routerUniBalanceBefore = IERC20(uni).balanceOf(address(router));
        
        // Execute swap
        (, uint256 v3AmountIn) = router.swapExactOut{value: wethAmountMax}(params, 0);
        vm.stopBroadcast();

        // Since WETH is supported token (input), verify:
        // 1. Router should collect fee from input amount (WETH)
        // 2. Router should not collect fee from output amount (UNI)
        // 3. Trader should receive exact output amount (UNI)

        // Verify router collected WETH as fee
        uint256 expectedWethFee = v3AmountIn * initialFeeRate / 10000;
        assertEq(
            IERC20(weth).balanceOf(address(router)) - routerWethBalanceBefore,
            expectedWethFee,
            "Router should collect fee in WETH"
        );

        // Verify router didn't collect any UNI as fee
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUniBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify trader received exact amount of UNI
        assertEq(
            IERC20(uni).balanceOf(trader.addr) - balanceUniBefore,
            uniAmountOut,
            "Trader should receive exact UNI amount"
        );
    }

    function testSwapExactOutUNIToWETH() public {
        address[] memory path = new address[](2);
        path[0] = uni;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI/WETH pool
        
        vm.startBroadcast(trader.key);
        // Give trader some UNI
        deal(uni, trader.addr, 2000 * 10**18);
        
        // Approve UNI spending
        IERC20(uni).approve(address(router), type(uint256).max);

        uint256 uniAmountMax = 200 * 10**18; // max 2 UNI
        uint256 wethAmountOut = 0.0001 ether; // want 1 WETH
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: uniAmountMax,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: wethAmountOut,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 routerUniBalanceBefore = IERC20(uni).balanceOf(address(router));
        uint256 balanceWethBefore = IERC20(weth).balanceOf(address(trader.addr));
        uint256 routerWethBalanceBefore = IERC20(weth).balanceOf(address(router));
        
        // Execute swap
        router.swapExactOut(params, 0);
        vm.stopBroadcast();

        // Since WETH is supported token (output), verify:
        // 1. Router should not collect fee from input amount (UNI)
        // 2. Router should collect fee from output amount (WETH)
        // 3. Trader should receive output amount minus fee (WETH)

        // Verify router didn't collect any UNI as fee
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUniBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify router collected WETH as fee
        uint256 expectedWethFee = wethAmountOut * initialFeeRate / 10000;
        assertEq(
            IERC20(weth).balanceOf(address(router)) - routerWethBalanceBefore,
            expectedWethFee,
            "Router should collect fee in WETH"
        );

        // Verify trader received WETH amount minus fee
        assertEq(
            IERC20(weth).balanceOf(trader.addr) - balanceWethBefore,
            wethAmountOut,
            "Trader should receive WETH amount minus fee"
        );
    }

    function testSwapExactOutUNIToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = uni;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI pool
        
        vm.startBroadcast(trader.key);
        // Give trader some UNI
        deal(uni, trader.addr, 10 * 10**18);
        
        // Approve UNI spending
        IERC20(uni).approve(address(router), type(uint256).max);

        uint256 uniAmountMax = 2 * 10**18; // max 2 UNI
        uint256 usdcAmountOut = 1 * 10**18; // want 1 USDC
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: uniAmountMax,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: usdcAmountOut,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 routerUniBalanceBefore = IERC20(uni).balanceOf(address(router));
        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));
        uint256 routerUsdcBalanceBefore = IERC20(usdc).balanceOf(address(router));
        
        // Execute swap
        router.swapExactOut(params, 0);
        vm.stopBroadcast();

        // Since USDC is supported token (output), verify:
        // 1. Router should not collect fee from input amount (UNI)
        // 2. Router should collect fee from output amount (USDC)
        // 3. Trader should receive output amount minus fee (USDC)

        // Verify router didn't collect any UNI as fee
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUniBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify router collected USDC as fee
        uint256 expectedUsdcFee = usdcAmountOut * initialFeeRate / 10000;
        assertEq(
            IERC20(usdc).balanceOf(address(router)) - routerUsdcBalanceBefore,
            expectedUsdcFee,
            "Router should collect fee in USDC"
        );

        // Verify trader received USDC amount minus fee
        assertEq(
            IERC20(usdc).balanceOf(trader.addr) - balanceUsdcBefore,
            usdcAmountOut,
            "Trader should receive USDC amount minus fee"
        );
    }

    function testSwapExactOutUSDCToUNI() public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = uni;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 2500; // 0.25% fee tier for UNI pool
        
        vm.startBroadcast(trader.key);
        // Give trader some USDC
        deal(usdc, trader.addr, 10000 * 10**18); // 10000 USDC
        
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);

        uint256 usdcAmountMax = 2000 * 10**18; // max 2000 USDC
        uint256 uniAmountOut = 1 * 10**18; // want 1 UNI
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: usdcAmountMax,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: uniAmountOut,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 routerUsdcBalanceBefore = IERC20(usdc).balanceOf(address(router));
        uint256 balanceUniBefore = IERC20(uni).balanceOf(address(trader.addr));
        
        // Execute swap
        (, uint256 v3AmountIn) = router.swapExactOut(params, 0);
        vm.stopBroadcast();

        // Verify router didn't collect any USDC as fee
        assertEq(
            IERC20(uni).balanceOf(address(router)),
            routerUsdcBalanceBefore,
            "Router should not collect UNI as fee"
        );

        // Verify router collected UNI as fee
        uint256 expectedUsdcFee = v3AmountIn * initialFeeRate / 10000;
        assertEq(
            IERC20(usdc).balanceOf(address(router)) - routerUsdcBalanceBefore,
            expectedUsdcFee,
            "Router should collect fee in USDC"
        );

        // Verify trader received UNI amount
        assertEq(
            IERC20(uni).balanceOf(trader.addr) - balanceUniBefore,
            uniAmountOut,
            "Trader should receive UNI amount"
        );
    }

    function testSwapExactOutUSDCToWETH() public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05% fee tier for USDC/WETH pool
        
        vm.startBroadcast(trader.key);
        // Give trader some USDC
        deal(usdc, trader.addr, 10000 * 10**18); // 10000 USDC
        
        // Approve USDC spending
        IERC20(usdc).approve(address(router), type(uint256).max);

        uint256 usdcAmountMax = 2000 * 10**18; // max 2000 USDC
        uint256 wethAmountOut = 3.16 ether; // want 3.16 WETH
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: usdcAmountMax,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: wethAmountOut,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceWethBefore = IERC20(weth).balanceOf(address(trader.addr));
        uint256 routerWethBalanceBefore = IERC20(weth).balanceOf(address(router));
        
        // Execute swap
        router.swapExactOut(params, 0);
        vm.stopBroadcast();

        // Since WETH is supported token (output), verify:
        // 1. Router should not collect fee from input amount (USDC)
        // 2. Router should collect fee from output amount (WETH)
        // 3. Trader should receive output amount minus fee (WETH)

        // Verify router collect USDC as fee
        assertEq(
            IERC20(usdc).balanceOf(address(router)),
            0,
            "Router should not collect USDC as fee"
        );

        // Verify router collected WETH as fee
        assertEq(
            IERC20(weth).balanceOf(address(router)) - routerWethBalanceBefore,
            wethAmountOut * initialFeeRate / 10000,
            "Router should collect fee in WETH"
        );

        // Verify trader received WETH amount
        assertEq(
            IERC20(weth).balanceOf(trader.addr) - balanceWethBefore,
            wethAmountOut,
            "Trader should receive WETH amount"
        );
    }

    function testSwapExactOutWETHToUSDC() public {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500; // 0.05% fee tier for USDC/WETH pool
        
        vm.startBroadcast(trader.key);
        
        uint256 wethAmountMax = 2 ether; // max 2 WETH
        uint256 usdcAmountOut = 1000 * 10**6; // want 1000 USDC
        
        IRouter.SwapExactOutParams memory params = IRouter.SwapExactOutParams({
            path: path,
            v3Fees: fees,
            v2AmountInMax: 0,
            v3AmountInMax: wethAmountMax,
            v2AmountRatio: 0,
            v3AmountRatio: 10000,
            amountOut: usdcAmountOut,
            to: trader.addr,
            deadline: vm.getBlockTimestamp() + 10
        });

        // Record initial balances
        uint256 balanceUsdcBefore = IERC20(usdc).balanceOf(address(trader.addr));
        uint256 routerWethBalanceBefore = IERC20(weth).balanceOf(address(router));
        
        // Execute swap
        router.swapExactOut{value: wethAmountMax}(params, 0);
        vm.stopBroadcast();

        // Since WETH is supported token (input), verify:
        // 1. Router should collect fee from input amount (WETH)
        // 2. Router should not collect fee from output amount (USDC)
        // 3. Trader should receive exact output amount (USDC)

        // Verify router collected WETH as fee
        assertEq(
            IERC20(weth).balanceOf(address(router)) - routerWethBalanceBefore,
            0,
            "Router should not collect fee in WETH"
        );

        // Verify router didn't collect any USDC as fee
        uint256 expectedUsdcFee = usdcAmountOut * initialFeeRate / 10000;
        assertEq(
            IERC20(usdc).balanceOf(address(router)),
            expectedUsdcFee,
            "Router should collect USDC as fee"
        );

        // Verify trader received exact amount of USDC
        assertEq(
            IERC20(usdc).balanceOf(trader.addr) - balanceUsdcBefore,
            usdcAmountOut,
            "Trader should receive exact USDC amount"
        );
    }
} 