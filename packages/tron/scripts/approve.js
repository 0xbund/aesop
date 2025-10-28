require('dotenv').config();
const { TronWeb } = require('tronweb');

const privateKey = process.env.PRIVATE_KEY;

const tronWeb = new TronWeb({
  fullHost: 'https://api.trongrid.io',
  privateKey: privateKey
})

// Contract addresses
const wtrxContractAddress = 'TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR'; // WTRX contract
const routerAddress = 'TV7zbgK4CDouSwBvJap4fz2257kaEe1Qyr';      // Router contract to approve

// ABI for the USDT contract
const ABI = [/* 为了简洁，这里省略了完整ABI */
  {
    "constant": false,
    "inputs": [
      {
        "name": "_spender",
        "type": "address"
      },
      {
        "name": "_value",
        "type": "uint256"
      }
    ],
    "name": "approve",
    "outputs": [
      {
        "name": "",
        "type": "bool"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const main = async () => {
  try {
    // Get the sender's address
    const fromAddress = tronWeb.address.fromPrivateKey(privateKey);
    console.log('From address:', fromAddress);

    // Initialize the USDT contract
    const usdtContract = await tronWeb.contract(ABI, wtrxContractAddress);

    // Amount to approve (using a very large number to avoid frequent approvals)
    const approveAmount = '115792089237316195423570985008687907853269984665640564039457584007913129639935'; // uint256 max value

    // Send approve transaction
    const result = await usdtContract.approve(
      routerAddress,
      approveAmount
    ).send({
      feeLimit: 100000000
    });

    console.log('Approval transaction successful:', result);

  } catch (error) {
    console.error('Error:', error);
    if (error.error) {
      console.error('Details:', JSON.stringify(error.error, null, 2));
    }
  }
};

main().catch(console.error); 