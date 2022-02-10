require('@nomiclabs/hardhat-waffle');
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ganache");
const dotenv = require('dotenv');
dotenv.config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

task("verify_contract","verifying all contract",async(taskArgs,hre) =>{
    // await hre.run("verify:verify", {
    //     address: "0x6E9d361c6351DdF0e053b23Af89D9637868B41F3",
    //     constructorArguments: [
    //     ],
    //     });
    // await hre.run("verify:verify", {
    // address: "0x4Ba1C9a29c0c497FcE1521580d41fC7cEDC1CcA3",
    // constructorArguments: [
    //     ["0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3","0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d","0x55d398326f99059fF775485246999027B3197955"],"0x87d9A6910f87725e0FDcF25a0B60c79a6c58680e","0xc805317Dcb3b2E96e78bF626d7B6ED070Ba64779","0x3FC12C449632687ed1fF5c1068A176E4626ea00e","0x20dD23fFB5d766eFF6E22Dd2B7bEA8A80EB370b8"
    // ],
    // });
    // await hre.run("verify:verify", {
    // address: "0x403A55DE5617a20081659A446bb560b696148401",
    // constructorArguments: ["0x76CD880b419371f1eDA12972C60F302eCa5D71AF","0x7808a48ce841A558fe3859051C8AE9AF547CB33D"
    // ],
    // })
    // await hre.run("verify:verify", {
    // address: "0x7E00338097Ad4397a39Af5E2b36012348fD87D8B",
    // constructorArguments: [
    //     "FOOTBALL","FBL","https://nft4play.pigeonflightclub.com/uri/medal/metadata/",[1,10000000,20000000,30000000,40000000]
    // ],
    // });
})


module.exports = {
    networks: {
    	testnet: {
      		url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      		chainId: 97,
      		accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    	},
    	mainnet: {
      		url: "https://bsc-dataseed.binance.org/",
      		chainId: 56,
      		accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    	},
    	localhost: {
      		url: "http://127.0.0.1:8545"
    	},
        bsc: {
            url: process.env.MAIN_NET_API_URL,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY],
        },
        fork: {
            url: 'http://localhost:8545',
        },
        hardhat: {
            forking: {
                url: process.env.MAIN_NET_API_URL,
            }
        },
    },
    etherscan: {
        apiKey: process.env.BSCSCAN_API_KEY,
    },
    solidity: {
        version: "0.8.11",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
};