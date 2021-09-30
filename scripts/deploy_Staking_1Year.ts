const hre = require("hardhat");
import { BigNumber } from "@ethersproject/bignumber";
import { Contract } from "@ethersproject/contracts";
import { run, ethers } from "hardhat";
import * as fs from "fs";

async function main() {
    await run("compile");
    const [deployer, account1] = await hre.ethers.getSigners();

    // Cleaning result file
    fs.writeFileSync("result.txt", "");

    console.log("deploying with address: " + deployer.address);
    console.log(
        "Account balance:",
        (await deployer.getBalance()).toString() + " BNB"
    );
    let COCAddress = "0xbdc3b3639f7aa19e623a4d603a3fb7ab20115a91"; // PROD CONTRACT
    console.log(`coc token contract: ${COCAddress}`);

    const name = "Staking 1 Year"
    const stakingStarts = 1632758400
    const stakingEnds = 1633363200
    const withdrawStart = 1664899200
    const stakingCap = BigNumber.from(125).mul(100000000000).mul(1000000000000000).mul(1000)


    const stakingConstructor = [
        name,
        COCAddress,
        stakingStarts,
        stakingEnds,
        withdrawStart,
        stakingCap,
    ];

    const stakingFactory = await hre.ethers.getContractFactory("Staking");
    const staking = await stakingFactory.deploy(
        stakingConstructor[0],
        stakingConstructor[1],
        stakingConstructor[2],
        stakingConstructor[3],
        stakingConstructor[4],
        stakingConstructor[5],
    );

    // Verifying contracts
    if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
        await new Promise((f) => setTimeout(f, 5000));
        await run("verify:verify", {
            address: staking.address,
            constructorArguments: stakingConstructor,
        });

        const COCFactory = await hre.ethers.getContractFactory("COC");
        const coc = await COCFactory.attach(COCAddress);
        await coc.addAdmin(staking.address);
        await coc.excludeFromFee(staking.address);
    }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
