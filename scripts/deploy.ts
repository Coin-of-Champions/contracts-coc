import hardhat from "hardhat";
const { run, ethers } = hardhat;
import { Contract } from "@ethersproject/contracts";
import * as fs from "fs";
import { BigNumber } from "ethers";

async function main(): Promise<void> {
  await run("compile");
  const [deployer] = await ethers.getSigners();

  const adminAddress = "0x756E54D763F5F97acC7b46bB7cC82d1D1839c2Db";

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Set deploy
  const CocFactory = await ethers.getContractFactory("COC");
  const cocContract = await CocFactory.deploy(
    "Coin of the champions",
    "COC",
    18,
    3,
    3
  );
  console.log("Manager deployed COC contract to:", cocContract.address);

  // Verifying contracts
  if (
    hardhat.network.name !== "hardhat" &&
    hardhat.network.name !== "localhost"
  ) {
    await new Promise((f) => setTimeout(f, 5000));

    await run("verify:verify", {
      address: cocContract.address,
      constructorArguments: ["Coin of the champions", "COC", 18, 3, 3],
    });

  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
