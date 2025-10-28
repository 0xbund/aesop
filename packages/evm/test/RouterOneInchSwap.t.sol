// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Router.sol";
import "./mocks/MockOneInchRouter.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// 單一案例：原生 ETH -> ERC20（未支援），手續費從輸入端（ETH）收取
contract RouterSwapNativeToERC20Test is Test {
    using Math for uint256;

    Router public router;
    MockOneInchRouter public mock1inch;
    ERC20Mock public dai;
    ERC20Mock public usdt;
    ERC20Mock public weth;
    address public admin;
    address public user;

    uint256 public constant FEE_RATE = 30; // 0.3%
    uint256 public constant FEE_DENOMINATOR = 1e4;
    address public constant NATIVE_PLACEHOLDER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // 1inch swap selector
    bytes4 private constant SWAP_SELECTOR = 0x7c025200;

    // Mirror Router's event for expectEmit
    event Swap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");

        dai = new ERC20Mock();
        usdt = new ERC20Mock();
        weth = new ERC20Mock();
        mock1inch = new MockOneInchRouter();

        // 簡化：WRAPPED_TOKEN 用 0、USDT_TOKEN 用隨意地址
        router = new Router(
            admin,
            address(0),
            address(0),
            address(mock1inch),
            address(weth),
            address(usdt),
            NATIVE_PLACEHOLDER,
            FEE_RATE
        );

        // 移轉 1inch 模擬器的所有權給 admin，好讓 admin 可設定額外退回的 ETH（模擬 aggregator 退款）
        mock1inch.transferOwnership(admin);

        // 準備資產與 mock 行為
        dai.mint(address(mock1inch), 10000 * 1e18);
        weth.mint(address(mock1inch), 10000 * 1e18);
        vm.deal(address(mock1inch), 1000 ether);
        vm.deal(user, 100 ether);
        // 預先給 mock 合約充足的 ERC20，因為輸出端會從 mock 轉給 Router
        // 原本的 setDefault 已不再需要
    }

    // native -> erc20
    function test_NativeToERC20() public {
        uint256 amountIn = 1 ether;
        uint256 expectedFee = amountIn.mulDiv(FEE_RATE, FEE_DENOMINATOR); // 由輸入端收取 ETH 手續費
        uint256 amountFor1inch = amountIn - expectedFee; // Router 只會把扣完費的金額送進 1inch
        uint256 expectedOutput = amountFor1inch * 2; // mock 以 1:2 匯率輸出 ERC20

        uint256 userEthBefore = user.balance;
        uint256 userDaiBefore = dai.balanceOf(user);
        uint256 routerEthBefore = address(router).balance;
        uint256 routerDaiBefore = dai.balanceOf(address(router));

        console2.log("amountIn:", amountIn);
        console2.log("expectedFee:", expectedFee);
        console2.log("amountFor1inch:", amountFor1inch);
        console2.log("expectedOutput:", expectedOutput);

        // calldata: (inputToken, outputToken, amountIn)
        bytes memory callData = abi.encodeWithSelector(
            SWAP_SELECTOR,
            NATIVE_PLACEHOLDER,
            address(dai),
            amountFor1inch
        );

        // Expect Router to emit Swap with net amounts
        vm.expectEmit(address(router));
        emit Swap(user, address(weth), address(dai), amountFor1inch, expectedOutput);

        vm.startPrank(user);
        uint256 returnAmount = router.swapOn1inch{value: amountIn}(
            IRouter.OneInchSwapParams({
                oneInchCallData: callData,
                inputToken: NATIVE_PLACEHOLDER,
                outputToken: address(dai),
                amountIn: amountIn,
                minOutputAmount: expectedOutput
            }),
            0
        );
        vm.stopPrank();

        // Also emit DS-Test logs so they show up clearly regardless of trace verbosity
        emit log_named_uint("amountIn", amountIn);
        emit log_named_uint("expectedFee", expectedFee);
        emit log_named_uint("amountFor1inch", amountFor1inch);
        emit log_named_uint("expectedOutput", expectedOutput);
        emit log_named_uint("returnAmount", returnAmount);
        emit log_named_uint("user ETH before", userEthBefore);
        emit log_named_uint("user ETH after", user.balance);
        emit log_named_uint("user DAI before", userDaiBefore);
        emit log_named_uint("user DAI after", dai.balanceOf(user));
        emit log_named_uint("router ETH before", routerEthBefore);
        emit log_named_uint("router ETH after", address(router).balance);
        emit log_named_uint("router DAI before", routerDaiBefore);
        emit log_named_uint("router DAI after", dai.balanceOf(address(router)));

        // 回傳值為實際發給使用者的 ERC20 數量
        assertEq(returnAmount, expectedOutput, "returnAmount");

        // 使用者應收到 ERC20，ETH 減少 amountIn（扣費已在合約內保留）
        assertEq(user.balance, userEthBefore - amountIn, "user ETH");
        assertEq(dai.balanceOf(user), userDaiBefore + expectedOutput, "user DAI");

        // 路由器僅留下 ETH 手續費，沒有 ERC20 殘留
        assertEq(address(router).balance, routerEthBefore + expectedFee, "router ETH fee");
        assertEq(dai.balanceOf(address(router)), routerDaiBefore, "router DAI residual");
    }

    // weth -> erc20
    function test_WrappedToERC20() public {
        uint256 amountIn = 2 ether;
        uint256 expectedFee = amountIn.mulDiv(FEE_RATE, FEE_DENOMINATOR); // 由輸入端（WETH）收取手續費
        uint256 amountFor1inch = amountIn - expectedFee;
        uint256 expectedOutput = amountFor1inch * 2; // 輸出 DAI（未支援）

        // 使用者準備 WETH 並授權 Router
        weth.mint(user, amountIn);
        vm.startPrank(user);
        weth.approve(address(router), amountIn);

        // calldata: (inputToken, outputToken, amountIn)
        bytes memory callData = abi.encodeWithSelector(
            SWAP_SELECTOR,
            address(weth),
            address(dai),
            amountFor1inch
        );

        uint256 userWethBefore = weth.balanceOf(user);
        uint256 userDaiBefore = dai.balanceOf(user);
        uint256 routerWethBefore = weth.balanceOf(address(router));
        uint256 routerDaiBefore = dai.balanceOf(address(router));

        // Expect Router to emit Swap with net amounts
        vm.expectEmit(address(router));
        emit Swap(user, address(weth), address(dai), amountFor1inch, expectedOutput);

        uint256 returnAmount = router.swapOn1inch(
            IRouter.OneInchSwapParams({
                oneInchCallData: callData,
                inputToken: address(weth),
                outputToken: address(dai),
                amountIn: amountIn,
                minOutputAmount: expectedOutput
            }),
            0
        );
        vm.stopPrank();

        // emits for important results
        emit log_named_uint("amountIn", amountIn);
        emit log_named_uint("expectedFee", expectedFee);
        emit log_named_uint("amountFor1inch", amountFor1inch);
        emit log_named_uint("expectedOutput", expectedOutput);
        emit log_named_uint("returnAmount", returnAmount);
        emit log_named_uint("user WETH before", userWethBefore);
        emit log_named_uint("user WETH after", weth.balanceOf(user));
        emit log_named_uint("user DAI before", userDaiBefore);
        emit log_named_uint("user DAI after", dai.balanceOf(user));
        emit log_named_uint("router WETH before", routerWethBefore);
        emit log_named_uint("router WETH after", weth.balanceOf(address(router)));
        emit log_named_uint("router DAI before", routerDaiBefore);
        emit log_named_uint("router DAI after", dai.balanceOf(address(router)));

        // 驗證
        assertEq(returnAmount, expectedOutput, "returnAmount");
        assertEq(weth.balanceOf(user), userWethBefore - amountIn, "user WETH");
        assertEq(dai.balanceOf(user), userDaiBefore + expectedOutput, "user DAI");
        // Router 應保留 WETH 手續費
        assertEq(weth.balanceOf(address(router)), routerWethBefore + expectedFee, "router WETH fee");
        assertEq(dai.balanceOf(address(router)), routerDaiBefore, "router DAI residual");
        // PVE-2: Verify allowance is cleared after swap
        assertEq(weth.allowance(address(router), address(mock1inch)), 0, "router allowance to 1inch should be 0");
    }

    // erc20 -> weth
    function test_ERC20ToWrapped() public {
        uint256 amountIn = 3 ether;
        uint256 amountFor1inch = amountIn; // 輸入端（DAI）未支援，輸入不收費
        uint256 rawOutput = amountFor1inch * 2; // 輸出 WETH（受支援）
        uint256 expectedFee = rawOutput.mulDiv(FEE_RATE, FEE_DENOMINATOR); // 由輸出端（WETH）收費
        uint256 expectedOutputToUser = rawOutput - expectedFee;

        // 使用者準備 DAI 並授權 Router
        dai.mint(user, amountIn);
        vm.startPrank(user);
        dai.approve(address(router), amountIn);

        // calldata: (inputToken, outputToken, amountIn)
        bytes memory callData = abi.encodeWithSelector(
            SWAP_SELECTOR,
            address(dai),
            address(weth),
            amountFor1inch
        );

        uint256 userDaiBefore = dai.balanceOf(user);
        uint256 userWethBefore = weth.balanceOf(user);
        uint256 routerDaiBefore = dai.balanceOf(address(router));
        uint256 routerWethBefore = weth.balanceOf(address(router));

        // Expect Router to emit Swap with net amounts
        vm.expectEmit(address(router));
        emit Swap(user, address(dai), address(weth), amountIn, expectedOutputToUser);

        uint256 returnAmount = router.swapOn1inch(
            IRouter.OneInchSwapParams({
                oneInchCallData: callData,
                inputToken: address(dai),
                outputToken: address(weth),
                amountIn: amountIn,
                minOutputAmount: expectedOutputToUser
            }),
            0
        );
        vm.stopPrank();

        // emits for important results
        emit log_named_uint("amountIn", amountIn);
        emit log_named_uint("rawOutput", rawOutput);
        emit log_named_uint("expectedFee", expectedFee);
        emit log_named_uint("expectedOutputToUser", expectedOutputToUser);
        emit log_named_uint("returnAmount", returnAmount);
        emit log_named_uint("user DAI before", userDaiBefore);
        emit log_named_uint("user DAI after", dai.balanceOf(user));
        emit log_named_uint("user WETH before", userWethBefore);
        emit log_named_uint("user WETH after", weth.balanceOf(user));
        emit log_named_uint("router DAI before", routerDaiBefore);
        emit log_named_uint("router DAI after", dai.balanceOf(address(router)));
        emit log_named_uint("router WETH before", routerWethBefore);
        emit log_named_uint("router WETH after", weth.balanceOf(address(router)));

        // returnAmount 是實際發給使用者的 WETH（已扣費）
        assertEq(returnAmount, expectedOutputToUser, "returnAmount");
        assertEq(dai.balanceOf(user), userDaiBefore - amountIn, "user DAI");
        assertEq(weth.balanceOf(user), userWethBefore + expectedOutputToUser, "user WETH");
        // Router 應保留 WETH 手續費
        assertEq(weth.balanceOf(address(router)), routerWethBefore + expectedFee, "router WETH fee");
        assertEq(dai.balanceOf(address(router)), routerDaiBefore, "router DAI residual");
        // PVE-2: Verify allowance is cleared after swap
        assertEq(dai.allowance(address(router), address(mock1inch)), 0, "router allowance to 1inch should be 0");
    }

    // erc20 -> native
    function test_ERC20ToNative() public {
        uint256 amountIn = 4 ether;
        uint256 amountFor1inch = amountIn; // 輸入端（DAI）未支援，輸入不收費
        uint256 rawOutput = amountFor1inch * 2; // 輸出為原生 ETH（受支援）
        uint256 expectedFee = rawOutput.mulDiv(FEE_RATE, FEE_DENOMINATOR); // 由輸出端（ETH）收費
        uint256 expectedOutputToUser = rawOutput - expectedFee;

        // 使用者準備 DAI 並授權 Router
        dai.mint(user, amountIn);
        vm.startPrank(user);
        dai.approve(address(router), amountIn);

        // calldata: (inputToken, outputToken, amountIn)
        bytes memory callData = abi.encodeWithSelector(
            SWAP_SELECTOR,
            address(dai),
            NATIVE_PLACEHOLDER,
            amountFor1inch
        );

        uint256 userEthBefore = user.balance;
        uint256 userDaiBefore = dai.balanceOf(user);
        uint256 routerEthBefore = address(router).balance;
        uint256 routerDaiBefore = dai.balanceOf(address(router));

        // Expect Router to emit Swap with net amounts
        vm.expectEmit(address(router));
        emit Swap(user, address(dai), address(weth), amountIn, expectedOutputToUser);

        uint256 returnAmount = router.swapOn1inch(
            IRouter.OneInchSwapParams({
                oneInchCallData: callData,
                inputToken: address(dai),
                outputToken: NATIVE_PLACEHOLDER,
                amountIn: amountIn,
                minOutputAmount: expectedOutputToUser
            }),
            0
        );
        vm.stopPrank();

        // emits for important results
        emit log_named_uint("amountIn", amountIn);
        emit log_named_uint("rawOutput", rawOutput);
        emit log_named_uint("expectedFee", expectedFee);
        emit log_named_uint("expectedOutputToUser", expectedOutputToUser);
        emit log_named_uint("returnAmount", returnAmount);
        emit log_named_uint("user DAI before", userDaiBefore);
        emit log_named_uint("user DAI after", dai.balanceOf(user));
        emit log_named_uint("user ETH before", userEthBefore);
        emit log_named_uint("user ETH after", user.balance);
        emit log_named_uint("router DAI before", routerDaiBefore);
        emit log_named_uint("router DAI after", dai.balanceOf(address(router)));
        emit log_named_uint("router ETH before", routerEthBefore);
        emit log_named_uint("router ETH after", address(router).balance);

        // returnAmount 是實際發給使用者的 ETH（已扣費）
        assertEq(returnAmount, expectedOutputToUser, "returnAmount");
        assertEq(dai.balanceOf(user), userDaiBefore - amountIn, "user DAI");
        assertEq(user.balance, userEthBefore + expectedOutputToUser, "user ETH");
        // Router 應保留 ETH 手續費
        assertEq(address(router).balance, routerEthBefore + expectedFee, "router ETH fee");
        assertEq(dai.balanceOf(address(router)), routerDaiBefore, "router DAI residual");
        // PVE-2: Verify allowance is cleared after swap
        assertEq(dai.allowance(address(router), address(mock1inch)), 0, "router allowance to 1inch should be 0");
    }

    // refund surplus: ERC20 input not fully spent by 1inch (router refunds leftover to user)
    function test_RefundSurplus_ERC20Input() public {
        uint256 amountIn = 10 ether;
        uint256 to1inch = 6 ether; // 1inch will actually spend 6, leaving 4 as surplus at router

        // Prepare user tokens and approve router
        dai.mint(user, amountIn);
        vm.startPrank(user);
        dai.approve(address(router), amountIn);

        // Call data asks 1inch to use only `to1inch` (our mock consumes exactly amountIn in calldata)
        bytes memory callData = abi.encodeWithSelector(
            SWAP_SELECTOR,
            address(dai),
            address(weth),
            to1inch
        );

        uint256 userDaiBefore = dai.balanceOf(user);
        uint256 routerDaiBefore = dai.balanceOf(address(router));

        // Router thinks total allowance/input is amountIn, but we only pass amountIn as function param
        // The router will snapshot and refund any unspent amount (amountIn - actuallySpent - expectedRetention)
        uint256 expectedUserDaiAfter = userDaiBefore - amountIn; // user sends all to router first
        uint256 rawOutput = to1inch * 2;
        uint256 expectedFeeOnOutput = rawOutput.mulDiv(FEE_RATE, FEE_DENOMINATOR);
        uint256 minOutput = rawOutput - expectedFeeOnOutput;

        // Expect Router to emit Swap with net amounts (amountIn equals amountToSwap = amountIn)
        vm.expectEmit(address(router));
        emit Swap(user, address(dai), address(weth), amountIn, minOutput);

        uint256 returnAmount = router.swapOn1inch(
            IRouter.OneInchSwapParams({
                oneInchCallData: callData,
                inputToken: address(dai),
                outputToken: address(weth),
                amountIn: amountIn,
                minOutputAmount: minOutput
            }),
            0
        );
        vm.stopPrank();

        // Focused emits for refund metrics
        emit log_named_uint("[ERC20Refund] amountIn", amountIn);
        emit log_named_uint("[ERC20Refund] to1inch", to1inch);
        emit log_named_uint("[ERC20Refund] minOutput (net)", minOutput);
        emit log_named_uint("[ERC20Refund] returnAmount", returnAmount);
        emit log_named_uint("[ERC20Refund] user DAI before", userDaiBefore);
        emit log_named_uint("[ERC20Refund] user DAI after", dai.balanceOf(user));
        emit log_named_uint("[ERC20Refund] router DAI before", routerDaiBefore);
        emit log_named_uint("[ERC20Refund] router DAI after", dai.balanceOf(address(router)));

        // Router should have refunded (amountIn - to1inch) since fee is on output side in this route
        uint256 refunded = amountIn - to1inch;
        assertEq(dai.balanceOf(user), expectedUserDaiAfter + refunded, "user DAI refunded");
        assertEq(dai.balanceOf(address(router)), routerDaiBefore, "router DAI no residual");

        // Return amount equals minOutput (net to user)
        assertEq(returnAmount, minOutput, "returnAmount matches net output");
        
        // PVE-2: Verify allowance is cleared after swap
        assertEq(dai.allowance(address(router), address(mock1inch)), 0, "router allowance to 1inch should be 0");
    }

    // refund surplus: Native input extra ETH returned from aggregator should be forwarded back to user
    function test_RefundSurplus_NativeInputExtraETH() public {
        // Configure mock to send back an extra 0.1 ETH after swap
        vm.startPrank(admin);
        mock1inch.setExtraEthToReturn(0.1 ether);
        vm.stopPrank();

        uint256 amountIn = 1 ether;
        uint256 expectedFee = amountIn.mulDiv(FEE_RATE, FEE_DENOMINATOR);
        uint256 to1inch = amountIn - expectedFee;
        uint256 expectedOutput = to1inch * 2; // output ERC20

        bytes memory callData = abi.encodeWithSelector(
            SWAP_SELECTOR,
            NATIVE_PLACEHOLDER,
            address(dai),
            to1inch
        );

        uint256 userEthBefore = user.balance;
        uint256 routerEthBefore = address(router).balance;
        uint256 mockEthBefore = address(mock1inch).balance;

        // Expect Router to emit Swap with net amounts
        vm.expectEmit(address(router));
        emit Swap(user, address(weth), address(dai), to1inch, expectedOutput);

        vm.startPrank(user);
        uint256 returnAmount = router.swapOn1inch{value: amountIn}(
            IRouter.OneInchSwapParams({
                oneInchCallData: callData,
                inputToken: NATIVE_PLACEHOLDER,
                outputToken: address(dai),
                amountIn: amountIn,
                minOutputAmount: expectedOutput
            }),
            0
        );
        vm.stopPrank();

        // Focused emits for native surplus metrics
        emit log_named_uint("[NativeRefund] amountIn", amountIn);
        emit log_named_uint("[NativeRefund] expectedFee", expectedFee);
        emit log_named_uint("[NativeRefund] to1inch", to1inch);
        emit log_named_uint("[NativeRefund] extraETH", 0.1 ether);
        emit log_named_uint("[NativeRefund] expectedOutput (ERC20)", expectedOutput);
        emit log_named_uint("[NativeRefund] returnAmount", returnAmount);
        emit log_named_uint("[NativeRefund] user ETH before", userEthBefore);
        emit log_named_uint("[NativeRefund] user ETH after", user.balance);
        emit log_named_uint("[NativeRefund] router ETH before", routerEthBefore);
        emit log_named_uint("[NativeRefund] router ETH after", address(router).balance);
        emit log_named_uint("[NativeRefund] mock ETH before", mockEthBefore);
        emit log_named_uint("[NativeRefund] mock ETH after", address(mock1inch).balance);

        // Router holds fee only; the extra 0.1 ETH mocked by aggregator should be refunded to user by router
        assertEq(address(router).balance, routerEthBefore + expectedFee, "router keeps only fee");
        assertEq(address(mock1inch).balance, mockEthBefore + to1inch - 0.1 ether, "mock paid extra ETH back");
        assertEq(user.balance, userEthBefore - amountIn + 0.1 ether, "user received surplus ETH refund");

        // Return amount is ERC20 output, unaffected by extra ETH refund
        assertEq(returnAmount, expectedOutput, "returnAmount");
    }
}


