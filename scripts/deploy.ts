// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const KSDNUnbond = await ethers.getContractFactory("KSDNUnbond");
  const kSDN = await KSDNUnbond.deploy("kaco wrapped SDN", "kSDN", 10000, "0xFB83a67784F110dC658B19515308A7a95c2bA33A", 87, 7200 * 2);

  await kSDN.deployed();

  console.log("Greeter deployed to:", kSDN.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
