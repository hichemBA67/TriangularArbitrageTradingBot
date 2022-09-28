const { ethers } = require("hardhat");
const { expect, assert } = require("chai");
const { impersonateFundErc20 } = require("../utils/utilities");
const {
  abi,
} = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");

const provider = ethers.provider;

describe("Tringular Arbitrage Contract", () => {
  const baseTokenAddress = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
  const token0 = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82";
  const token1 = "0x2c094F5A7D1146BB93850f629501eB749f6Ed491";
  const whaleAddress = "0xf977814e90da44bfa03b6295a0616a897441acec";
  const dummyToken = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

  const factoryAddress = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73";
  const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
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
