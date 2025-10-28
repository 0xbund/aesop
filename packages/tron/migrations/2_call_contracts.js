const Router = artifacts.require('Router');
const { TronWeb, utils: TronWebUtils, Trx, TransactionBuilder, Contract, Event, Plugin } = require('tronweb');

module.exports = async function(deployer) {
  // 获取已部署的Router合约实例
  const router = await Router.deployed();
  
  // 读取合约状态变量
  const currentAdmin = await router.admin();
  const currentSmartRouter = await router.smartRouter();
  const currentWrappedToken = await router.WRAPPED_TOKEN();
  const currentFeeRate = await router.feeRate();
  // const currentFeeCollector = await router.feeCollector();
  
  console.log("合约信息:");
  console.log("管理员地址:", TronWebUtils.address.fromHex(currentAdmin));
  console.log("SmartRouter地址:", TronWebUtils.address.fromHex(currentSmartRouter));
  console.log("WrappedToken地址:", TronWebUtils.address.fromHex(currentWrappedToken));
  console.log("当前费率:", currentFeeRate.toString());
  // console.log("费用接收地址:", TronWebUtils.address.fromHex(currentFeeCollector));
  
  // 如果需要调用管理员函数，确保使用管理员账户
  // const accounts = await web3.eth.getAccounts();
  // const adminAccount = accounts[0];
  
  // // 示例：更新费率 (需要管理员权限)
  // await deployer.router.updateFeeRate(50); // 设置为 0.5%
  // console.log("更新费率成功:", await router.feeRate());
  
  // // 示例：更新费用接收地址 (需要管理员权限)
  // await router.updateFeeCollector("THMShqJoUSWL4qG9denR1aBB4g1tnWTDsy");
  // console.log("更新费用接收地址成功:", TronWebUtils.address.fromHex(await router.feeCollector() ));
};
