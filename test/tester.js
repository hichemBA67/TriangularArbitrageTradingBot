const { ethers } = require("hardhat");
const { expect, assert } = require("chai");
const { impersonateFundErc20 } = require("../utils/utilities");
const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

const provider = ethers.provider;

describe("Tringular Arbitrage Contract", () => {
  const baseTokenAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const token0 = "0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0";
  const token1 = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
  const whaleAddress = "0xf977814e90da44bfa03b6295a0616a897441acec";
  const dummyToken = "0xdAC17F958D2ee523a2206206994597C13D831ec7";

  const factoryAddress = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
  const routerAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const borrowAmountHuman = "0.1";
  const initialFundungAmount = "100";

  let borrowAmount,
    txArbitrage,
    whaleBalance,
    gasUsedUSD,
    baseTokenContract,
    TriangularFlashSwapContract,
    decimals;

  baseTokenContract = new ethers.Contract(baseTokenAddress, abi, provider);

  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    decimals = await baseTokenContract.decimals();

    whaleBalance = await provider.getBalance(whaleAddress);
    expect(whaleBalance).not.equal(0);

    const TriangularFlashSwapContractFactory = await ethers.getContractFactory(
      "TriangularFlashSwap"
    );
    TriangularFlashSwapContract =
      await TriangularFlashSwapContractFactory.deploy();
    await TriangularFlashSwapContract.deployed();

    borrowAmount = ethers.utils.parseUnits(borrowAmountHuman, decimals);

    await impersonateFundErc20(
      baseTokenContract,
      whaleAddress,
      TriangularFlashSwapContract.address,
      initialFundungAmount
    );
  });

  describe("Arbitrage execute", () => {
    it("Contract is funded", async () => {
      const TriangularFlashSwapContractBalance = ethers.utils.formatUnits(
        await TriangularFlashSwapContract.getTokenBalance(baseTokenAddress),
        decimals
      );

      expect(Number(TriangularFlashSwapContractBalance)).equal(
        Number(initialFundungAmount)
      );
    });

    it("Execute arbitrage", async () => {
      txArbitrage = await TriangularFlashSwapContract.startArbitrage(
        baseTokenAddress,
        borrowAmount,
        token0,
        token1,
        factoryAddress,
        routerAddress,
        dummyToken
      );

      assert(txArbitrage);

      const contractBalanceBaseToken =
        await TriangularFlashSwapContract.getTokenBalance(baseTokenAddress);

      const contractBalanceBaseTokenFormatted = ethers.utils.formatUnits(
        contractBalanceBaseToken,
        decimals
      );

      console.log(
        "Balance of base token: " +
          ethers.utils.formatUnits(contractBalanceBaseToken, decimals)
      );
    });
  });
});
