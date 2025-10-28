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
        "internalType": "struct IRouter.SwapExactInParams",
        "name": "params",
        "type": "tuple",
        "components": [
        {
          "internalType": "address[]",
          "name": "path",
          "type": "address[]"
        },
        {
          "internalType": "uint256",
          "name": "amountIn",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "v2AmountRatio",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "v3AmountRatio",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "v2AmountOutMin",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "v3AmountOutMin",
          "type": "uint256"
        },
        {
          "internalType": "uint24[]",
          "name": "v3Fees",
          "type": "uint24[]"
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
      ]
    },
    {
      "internalType": "uint256",
      "name": "routerFeeRate",
      "type": "uint256"
    }
  ],
  "stateMutability": "payable",
  "type": "function",
  "name": "swapExactIn",
  "outputs": [
    {
      "internalType": "uint256",
      "name": "v2AmountOut",
      "type": "uint256"
    },
    {
      "internalType": "uint256",
      "name": "v3AmountOut",
      "type": "uint256"
    }
  ]
},    {
  "inputs": [],
  "name": "v3Router",
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
  "name": "v2Router",
  "outputs": [
    {
      "internalType": "address",
      "name": "",
      "type": "address"
    }
  ],
  "stateMutability": "view",
  "type": "function"
}
]

const contractAddress = 'TBy5hdEy9wDoKaBDeELgKMgT8m3hJWC1Yy';

const main = async () => {
  try {
    const trxblance = await tronWeb.trx.getBalance(fromAddress);
    console.log('trxblance:', trxblance);
    
    const contract = await tronWeb.contract(abi, contractAddress);

    const v3Router = await contract.v3Router().call();
    const v2Router = await contract.v2Router().call();
    const v3RouterTronAddress = tronWeb.address.fromHex(v3Router);
    const v2RouterTronAddress = tronWeb.address.fromHex(v2Router);
    console.log('v3Router (Tron format):', v3RouterTronAddress);
    console.log('v2Router (Tron format):', v2RouterTronAddress);

    const params = {
      path: [
        "TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR",
        "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
      ],
      amountIn: "5000",
      v2AmountRatio: "10000",
      v3AmountRatio: "0",
      v2AmountOutMin: "0",
      v3AmountOutMin: "0",
      v3Fees: ["500"],
      to: "TZ8igyyTsRwUxMvhLBoAH8gstReJ97SsXL",
      deadline: (Math.floor(Date.now() / 1000) + 60 * 20).toString()
    };

    const routerFeeRate = "100";

    const result = await contract.swapExactIn(
      [
        params.path,
        params.amountIn,
        params.v2AmountRatio,
        params.v3AmountRatio,
        params.v2AmountOutMin,
        params.v3AmountOutMin,
        params.v3Fees,
        params.to,
        params.deadline
      ],
      routerFeeRate
    ).send({
      feeLimit: 100000000
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
