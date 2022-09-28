const { ethers } = require("hardhat");

async function main() {
  const [deployer] = ethers.getSigners();

  console.log("Deploying contract with the account: " + deployer.account);
  console.log("Account balance: " + (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("TriangularFlashSwap");
  const token = await Token.deploy();

  console.log("Token address: " + token.address);
}

main().then(() => {
  process.exit(0).catch((error) => {
    console.error(error);
    process.exit(1);
  });
});
