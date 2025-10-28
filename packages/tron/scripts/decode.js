require('dotenv').config();
const { TronWeb } = require('tronweb');

const privateKey = process.env.PRIVATE_KEY;

const tronWeb = new TronWeb({
  fullHost: 'https://api.trongrid.io',
  privateKey: privateKey
})

const { TronWeb, utils: TronWebUtils, Trx, TransactionBuilder, Contract, Event, Plugin } = require('tronweb');
var ethers = require('ethers')

const AbiCoder = ethers.utils.AbiCoder;
const ADDRESS_PREFIX_REGEX = /^(41)/;
const ADDRESS_PREFIX = "41";

//types:Parameter type list, if the function has multiple return values, the order of the types in the list should conform to the defined order
//output: Data before decoding
//ignoreMethodHash：Decode the function return value, fill falseMethodHash with false, if decode the data field in the gettransactionbyid result, fill ignoreMethodHash with true

async function decodeParams(types, output, ignoreMethodHash) {

    if (!output || typeof output === 'boolean') {
        ignoreMethodHash = output;
        output = types;
    }

    if (ignoreMethodHash && output.replace(/^0x/, '').length % 64 === 8)
        output = '0x' + output.replace(/^0x/, '').substring(8);

    const abiCoder = new AbiCoder();

    if (output.replace(/^0x/, '').length % 64)
        throw new Error('The encoded string is not valid. Its length must be a multiple of 64.');
    return abiCoder.decode(types, output).reduce((obj, arg, index) => {
        if (types[index] == 'address')
            arg = ADDRESS_PREFIX + arg.substr(2).toLowerCase();
        obj.push(arg);
        return obj;
    }, []);
}


async function main() {
    const selector = "swapExactInput(address[],string[],uint256[],uint24[],(uint256,uint256,address,uint256))"

    let data = '0e42d21a00000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000bb80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fe176b5513b7752fbb20e63671db457ac76b8ea700000000000000000000000000000000000000000000000000000000676e7ab100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000891cdb91d149f23b1a45d9c5ca78a88d0cb44c18000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002763200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'

//     const types = [
//       'address[]',      // 地址數組
//       'string[]',       // 字符串數組
//       'uint256[]',      // uint256 數組
//       'uint24[]',       // uint24 數組
//       'tuple(uint256,uint256,address,uint256)'  // 結構體
//   ]
    const types = [
      'address[]',      // 地址數組
      'string[]',       // 字符串數組
      'uint256[]',      // uint256 數組
      'uint24[]',       // uint24 數組
      'tuple(uint256,uint256,address,uint256)',  // 結構體
      'uint16'
    ]
  
  const result = await decodeParams(types, data, true)
  console.log(result)

//   const base582 = tronWeb.address.fromHex("0x0000000000000000000000000000000000000000");
//   console.log(base582)
  const base581 = tronWeb.address.fromHex("0x891cdb91d149f23B1a45D9c5Ca78a88d0cB44C18");
  console.log(base581)
  const base58 = tronWeb.address.fromHex("0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C");
  console.log(base58)

//   const tAddress = tronWeb.address.toHex("T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb");
//   console.log(tAddress)
}

main()
