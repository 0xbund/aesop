require('dotenv').config();
const { TronWeb, utils: TronWebUtils, Trx, TransactionBuilder, Contract, Event, Plugin } = require('tronweb');

const privateKey = process.env.PRIVATE_KEY;
const tronWeb = new TronWeb({
  fullHost: 'https://api.trongrid.io',
  privateKey: privateKey
})

const fromAddress = tronWeb.address.fromPrivateKey(privateKey);
console.log('fromAddress:', fromAddress);

const abi = [
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
      },
      {
        "internalType": "address",
        "name": "_initialFeeCollector",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "SafeERC20FailedOperation",
    "type": "error"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "newFeeCollector",
        "type": "address"
      }
    ],
    "name": "FeeCollectorUpdated",
    "type": "event"
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
    "type": "event"
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
    "inputs": [],
    "name": "feeCollector",
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
        "internalType": "address",
        "name": "_newAdmin",
        "type": "address"
      }
    ],
    "name": "transferAdmin",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_newFeeCollector",
        "type": "address"
      }
    ],
    "name": "updateFeeCollector",
    "outputs": [],
    "stateMutability": "nonpayable",
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
  }
];

const contractAddress = 'TGHmU2i94XE9wuZDvcFomfvXvEzi3CBq9G';

const main = async () => {
  try {
    const trxblance = await tronWeb.trx.getBalance(fromAddress);
    console.log('trxblance:', trxblance);
    
    const contract = await tronWeb.contract(abi, contractAddress);

    const WTRX_USDT_data = {
      "amountIn": "0.003000",
      "amountOut": "0.002462",
      "inUsd": "0.002464328983490208170000",
      "outUsd": "0.002459523821191292609200",
      "impact": "-0.000146",
      "fee": "0.000030",
      "tokens": [
          "TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR",
          "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
      ],
      "symbols": [
          "WTRX",
          "USDT"
      ],
      "poolFees": [
          "0",
          "0"
      ],
      "poolVersions": [
          "v2"
      ],
      "stepAmountsOut": [
          "0.002462"
      ]
    };

    const data = WTRX_USDT_data;

    let result = await contract.swapExactIn(
                    data.tokens,
                    data.poolVersions,
                    [2],
                    data.poolFees,
                    [
                      tronWeb.toSun(data.amountIn),
                      0,
                      fromAddress,
                      Math.floor(Date.now() / 1000) + 60 * 60 * 24 
                    ],
                    0
                ).send({
                  feeLimit: 10000 * 1e6,
                  callValue: tronWeb.toSun(data.amountIn)
              });

    console.log('Transaction result:', result);

  } catch (error) {
    console.error('Error:', error);
    if (error.error) {
      console.error('Details:', JSON.stringify(error.error, null, 2));
    }
  }
}

main().catch(console.error);
