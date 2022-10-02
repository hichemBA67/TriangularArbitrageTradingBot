require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      { version: "0.8.17" },
      { version: "0.8.8" },
      { version: "0.6.6" },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/BbytRtoFYjWaFZ9jr0KLvR9dSOxAaI1w",
      },
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      accounts: [
        "0x799fb58cc2d8ebe51ec450e362c234cca1d2acb0b3b0a0a2241bc62ba27f2451",
      ],
    },
    mainnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 56,
      accounts: [
        "0x799fb58cc2d8ebe51ec450e362c234cca1d2acb0b3b0a0a2241bc62ba27f2451",
      ],
    },
  },
};
