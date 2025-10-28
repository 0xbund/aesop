require('dotenv').config();
const {
  TronWeb,
  utils: TronWebUtils,
  Trx,
  TransactionBuilder,
  Contract,
  Event,
  Plugin,
} = require("tronweb");

const host = "https://api.trongrid.io";

const tronWeb = new TronWeb({
  fullHost: host,
  privateKey: process.env.PRIVATE_KEY
});

// 首先定义合约的 ABI
const contractABI = [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_admin",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_smartRouter",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_WRAPPED_TOKEN",
        "type": "address"
      },
      {
        "internalType": "uint16",
        "name": "_initialFeeRate",
        "type": "uint16"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "uint16",
        "name": "newFeeRate",
        "type": "uint16"
      }
    ],
    "name": "FeeRateUpdated",
    "type": "event",
    "stateMutability": "nonpayable"
  },
  {
    "inputs": [],
    "name": "WRAPPED_TOKEN",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "acceptAdminTransfer",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "admin",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "approve",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "feeRate",
    "outputs": [
      {
        "internalType": "uint16",
        "name": "",
        "type": "uint16"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "newAdmin",
        "type": "address"
      }
    ],
    "name": "initiateAdminTransfer",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pendingAdmin",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "smartRouter",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address[]",
        "name": "path",
        "type": "address[]"
      },
      {
        "internalType": "string[]",
        "name": "poolVersion",
        "type": "string[]"
      },
      {
        "internalType": "uint256[]",
        "name": "versionLen",
        "type": "uint256[]"
      },
      {
        "internalType": "uint24[]",
        "name": "fees",
        "type": "uint24[]"
      },
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "amountIn",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "amountOutMin",
            "type": "uint256"
          },
          {
            "internalType": "address",
            "name": "to",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "deadline",
            "type": "uint256"
          }
        ],
        "internalType": "struct IRouter.SwapData",
        "name": "data",
        "type": "tuple"
      },
      {
        "internalType": "uint16",
        "name": "routerFeeRate",
        "type": "uint16"
      }
    ],
    "name": "swapExactIn",
    "outputs": [
      {
        "internalType": "uint256[]",
        "name": "amountsOut",
        "type": "uint256[]"
      }
    ],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint16",
        "name": "_newFeeRate",
        "type": "uint16"
      }
    ],
    "name": "updateFeeRate",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "recipient",
        "type": "address"
      }
    ],
    "name": "withdrawToken",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const contract = new Contract(
  tronWeb,
  contractABI,
  "TGHmU2i94XE9wuZDvcFomfvXvEzi3CBq9G" // 合约地址
);

// 将代码包装在异步函数中并立即执行
const main = async () => {
  // 获取所有只读函数的值
  try {
    // 获取 WRAPPED_TOKEN 地址
    const wrappedToken = await contract.WRAPPED_TOKEN().call();
    console.log('WRAPPED_TOKEN:', tronWeb.address.fromHex(wrappedToken));
    // address public immutable smartRouter;
    // address public immutable WRAPPED_TOKEN;
    // address public admin;
    // address public pendingAdmin;
    // uint16 constant FEE_DENOMINATOR = 1e4;
    // uint16 public feeRate;

    // 获取智能路由地址
    const smartRouter = await contract.smartRouter().call();
    console.log('Smart Router:', tronWeb.address.fromHex(smartRouter));

    const admin = await contract.admin().call();
    console.log('Admin:', tronWeb.address.fromHex(admin));

    const pendingAdmin = await contract.pendingAdmin().call();
    console.log('Pending Admin:', tronWeb.address.fromHex(pendingAdmin));

    const feeRate = await contract.feeRate().call();
    console.log('Fee Rate:', feeRate.toString());
    // FEE_DENOMINATOR 是常量，无需从合约中读取
    console.log('Fee Denominator: 10000'); // 1e4
    
  } catch (error) {
    console.error('读取合约信息时发生错误:', error);
  }
};

main().catch(console.error);
