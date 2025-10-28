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
        "internalType": "struct SmartExchangeRouter.SwapData",
        "name": "data",
        "type": "tuple"
      }
    ],
    "name": "swapExactInput",
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
]

const contractAddress = 'TJ4NNy8xZEqsowCBhLvZ45LCqPdGjkET5j';

const main = async () => {
  try {
    const trxblance = await tronWeb.trx.getBalance(fromAddress);
    console.log('trxblance:', trxblance);
    
    const contract = await tronWeb.contract(abi, contractAddress);

    const TRX_USDT_data = {
      "amountIn": "0.0050000",
      "amountOut": "0.002449",
      "inUsd": "0.002449948252100681750000",
      "outUsd": "0.002446501771450822488400",
      "impact": "-0.000038",
      "fee": "0.000030",
      "tokens": [
          "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb",
          "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
      ],
      "symbols": [
          "TRX",
          "USDT"
      ],
      "poolFees": [
          "0",
          "0"
      ],
      "poolVersions": [
          "v1"
      ],
      "stepAmountsOut": [
          "0.002449"
      ]
  };

    const data = TRX_USDT_data;

    let result = await contract.swapExactInput(
                    data.tokens,
                    data.poolVersions,
                    [2],
                    data.poolFees,
                    [
                      tronWeb.toSun(data.amountIn),
                      0,
                      fromAddress,
                      Math.floor(Date.now() / 1000) + 60 * 60 * 24 
                    ]
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
