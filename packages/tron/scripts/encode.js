require('dotenv').config();
const { TronWeb } = require('tronweb');

const privateKey = process.env.PRIVATE_KEY;

const tronWeb = new TronWeb({
  fullHost: 'https://api.trongrid.io',
  privateKey: privateKey
})

const fromAddress = tronWeb.address.fromPrivateKey(privateKey);
console.log('fromAddress:', fromAddress);

const abi = [{
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
}]

const contractAddress = 'CONTRACT_ADDRESS';

const main = async () => {
  try {
    const contract = await tronWeb.contract(abi, contractAddress);

    const params = {
      path: [
        "TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR",
        "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
      ],
      amountIn: "10000",
      v2AmountRatio: "0",
      v3AmountRatio: "100000",
      v2AmountOutMin: "0",
      v3AmountOutMin: "0",
      v3Fees: ["3000"],
      to: "TO_ADDRESS",
      deadline: (Math.floor(Date.now() / 1000) + 60 * 20).toString()
    };

    const routerFeeRate = "100";

    const args = [
      [
        [
          "TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR",
          "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        ],
        params.amountIn,
        params.v2AmountRatio,
        params.v3AmountRatio,
        params.v2AmountOutMin,
        params.v3AmountOutMin,
        [
          3000
        ],
        params.to,
        params.deadline
      ], 
      routerFeeRate
    ];

    const parameter = tronWeb.utils.abi.encodeParamsV2ByABI(abi[0], args);
    console.log('parameter:', parameter);

    // const tx = await tronWeb.transactionBuilder.triggerSmartContract(
    //   contractAddress,
    //   functionSelector,
    //   {},
    //   parameter
    // );

    // const signedTx = await tronWeb.trx.sign(tx.transaction);

    // const result = await tronWeb.trx.sendRawTransaction(signedTx);

    // console.log('Transaction result:', result);

  } catch (error) {
    console.error('Error:', error);
    if (error.error) {
      console.error('Details:', JSON.stringify(error.error, null, 2));
    }
  }
}

main().catch(console.error);
