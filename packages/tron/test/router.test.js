const Router = artifacts.require("Router");
const MockToken = artifacts.require("MockToken");
const MockSmartRouter = artifacts.require("MockSmartRouter");

contract("Router", accounts => {
    // 定义测试所需变量
    let router;
    let wrappedToken;
    let smartRouter;
    const admin = accounts[0];
    const feeCollector = accounts[1];
    const user = accounts[2];
    const initialFeeRate = 100; // 1%
    
    // 在每个测试用例前部署合约
    beforeEach(async () => {
        try {
            // 添加一个小延迟以避免重复交易
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // 部署相关合约
            wrappedToken = await MockToken.new(
                "Wrapped TRX",
                "WTRX",
                {from: admin}
            );
            
            // 在部署 MockSmartRouter 之前添加延迟
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            smartRouter = await MockSmartRouter.new(
                {from: admin}
            );
            
            // 在部署 Router 之前添加延迟
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // 部署Router合约
            router = await Router.new(
                tronWeb.address.toHex(admin),
                smartRouter.address,
                wrappedToken.address,
                initialFeeRate,
                {from: admin}
            );
        } catch (error) {
            console.error("部署合约失败:", error);
            throw error;
        }
    });

    // 测试构造函数
    describe("Constructor", () => {
        it("should initialize with correct values", async () => {
            try {
                const actualAdmin = await router.admin();
                const actualSmartRouter = await router.smartRouter();
                const actualWrappedToken = await router.WRAPPED_TOKEN();
                const actualFeeRate = await router.feeRate();

                assert.equal(
                    tronWeb.address.fromHex(actualAdmin),
                    admin,
                    "Admin address not set correctly"
                );
                assert.equal(
                    actualSmartRouter,
                    smartRouter.address,
                    "Smart router address not set correctly"
                );
                assert.equal(
                    actualWrappedToken,
                    wrappedToken.address,
                    "Wrapped token address not set correctly"
                );
                assert.equal(
                    actualFeeRate,
                    initialFeeRate,
                    "Fee rate not set correctly"
                );
            } catch (error) {
                console.error("测试失败:", error);
                throw error;
            }
        });
    });

    // 测试管理员功能
    describe.only("Admin functions", () => {

        it("should update fee rate successfully", async () => {
            const newFeeRate = 200; // 2%
            await router.updateFeeRate(newFeeRate, {from: admin});
            const actualFeeRate = await router.feeRate();
            assert.equal(
                actualFeeRate,
                newFeeRate,
                "Fee rate not updated correctly"
            );
        });

        it("should withdraw token successfully", async () => {
            // 直接转入代币到路由合约
            const transferAmount = "1000000";
            await wrappedToken.transfer(router.address, transferAmount, {from: admin});
            
            // 获取提取前的余额
            const recipient = accounts[4];
            const recipientBalanceBefore = await wrappedToken.balanceOf(recipient);
            const routerBalance = await wrappedToken.balanceOf(router.address);
            
            // 确认路由合约收到了代币
            assert.equal(
                routerBalance.toString(),
                transferAmount,
                "Router should have received tokens"
            );

            // 提取代币
            const withdrawAmount = routerBalance;
            await router.withdrawToken(
                wrappedToken.address,
                withdrawAmount,
                recipient,
                {from: admin}
            );

            // 验证代币已被提取
            const recipientBalanceAfter = await wrappedToken.balanceOf(recipient);
            const routerBalanceAfter = await wrappedToken.balanceOf(router.address);

            assert.equal(
                routerBalanceAfter.toString(),
                "0",
                "Router balance should be 0 after withdrawal"
            );
            assert.equal(
                recipientBalanceAfter.sub(recipientBalanceBefore).toString(),
                withdrawAmount.toString(),
                "Tokens should be transferred to recipient"
            );
        });

        it("should approve tokens successfully", async () => {
            // 部署一个新的测试代币
            const testToken = await MockToken.new(
                "Test Token", 
                "TEST", 
                {
                    from: admin,
                    rawParameter: JSON.stringify({_nonce: Date.now()})
                }
            );
            
            // 先给路由合约转一些代币，确保有余额可以授权
            const amount = "1000000000";
            await testToken.transfer(router.address, amount, {from: admin});
            
            // 执行approve
            await router.approve(
                testToken.address, 
                amount, 
                {from: admin}  // 改为使用admin而不是user
            );
            
            // 检查授权额度
            const allowance = await testToken.allowance(
                router.address,
                smartRouter.address
            );
            
            const MAX_UINT256 = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
            
            assert.equal(
                allowance.toString(),
                MAX_UINT256,
                "Approval amount should be max uint256"
            );
        });

        it("should initiate and accept admin transfer successfully", async () => {
            const newAdmin = accounts[3];
            
            // 初始化管理员转移
            await router.initiateAdminTransfer(
                tronWeb.address.toHex(newAdmin),
                {from: admin}
            );
            
            // 验证 pendingAdmin 已正确设置
            const pendingAdminAfterInitiate = await router.pendingAdmin();
            assert.equal(
                tronWeb.address.fromHex(pendingAdminAfterInitiate),
                newAdmin,
                "Pending admin not set correctly"
            );
            
            // 新管理员接受转移
            await router.acceptAdminTransfer({from: newAdmin});
            
            // 验证管理员已更新且 pendingAdmin 已重置
            const actualAdmin = await router.admin();
            const pendingAdminAfterAccept = await router.pendingAdmin();
            
            assert.equal(
                tronWeb.address.fromHex(actualAdmin),
                newAdmin,
                "Admin not transferred correctly"
            );
            assert.equal(
                tronWeb.address.fromHex(pendingAdminAfterAccept),
                tronWeb.address.fromHex("410000000000000000000000000000000000000000"),
                "Pending admin not reset correctly"
            );
        });
    });

    // 测试交换功能
    describe("Swap functions", () => {
        it("should execute swapExactIn successfully with WTRX as first token", async () => {
            // 记录初始状态
            const initialFeeCollected = await wrappedToken.balanceOf(feeCollector);
            const userBalanceBefore = await wrappedToken.balanceOf(user);
            
            const path = [wrappedToken.address, accounts[5]];
            const poolVersion = ["v2.1"];
            const versionLen = [1];
            const fees = [300];
            const amountIn = "1000000";
            
            const swapData = {
                amountIn: amountIn,
                amountOutMin: 0,
                to: tronWeb.address.toHex(user),
                deadline: Math.floor(Date.now() / 1000) + 3600
            };

            // 执行交换
            await router.swapExactIn(
                path,
                poolVersion,
                versionLen,
                fees,
                swapData,
                0,
                {
                    from: user,
                    callValue: amountIn
                }
            );

            // 验证费用收集和用户余额
            const finalFeeCollected = await wrappedToken.balanceOf(feeCollector);
            const expectedFee = BigInt(amountIn) * BigInt(initialFeeRate) / BigInt(10000);
            
            assert.equal(
                (finalFeeCollected - initialFeeCollected).toString(),
                expectedFee.toString(),
                "Fee not collected correctly"
            );
        });

        it("should execute swapExactIn successfully with WTRX as last token", async () => {
            const mockToken = await MockToken.new("Test Token", "TEST", {from: admin});
            const path = [mockToken.address, wrappedToken.address];
            const poolVersion = ["v2.1"];
            const versionLen = [1];
            const fees = [300];
            const amountIn = "1000000";
            
            // 给用户转一些测试代币
            await mockToken.transfer(user, amountIn, {from: admin});
            await mockToken.approve(router.address, amountIn, {from: user});
            
            const swapData = {
                amountIn: amountIn,
                amountOutMin: 0,
                to: tronWeb.address.toHex(user),
                deadline: Math.floor(Date.now() / 1000) + 3600
            };

            // 记录初始状态
            const initialFeeCollectorBalance = await wrappedToken.balanceOf(feeCollector);
            const userBalanceBefore = await wrappedToken.balanceOf(user);

            // 执行交换
            await router.swapExactIn(
                path,
                poolVersion,
                versionLen,
                fees,
                swapData,
                0,
                {from: user}
            );
            
            // 验证费用收集和用户收到的代币
            const finalFeeCollectorBalance = await wrappedToken.balanceOf(feeCollector);
            const userBalanceAfter = await wrappedToken.balanceOf(user);
            
            // 计算预期的交换后金额
            const expectedFee = BigInt(amountIn) * BigInt(initialFeeRate) / BigInt(10000);
            
            assert.equal(
                (finalFeeCollectorBalance - initialFeeCollectorBalance).toString(),
                expectedFee.toString(),
                "Fee not collected correctly"
            );
            
            // 验证用户收到的代币数量增加
            assert(
                userBalanceAfter > userBalanceBefore,
                "User should receive tokens"
            );
        });
    });
});
