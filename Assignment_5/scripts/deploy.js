const hre = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();

  const Name = "SocialFi";
  const Contract = await hre.ethers.getContractFactory(Name);

  const param1 = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
  const param2 = 5;
  const param3 = "ipfs://QmSPdJyCiJCbJ2sWnomh6gHqkT2w1FSnp7ZnXxk3itvc14/";
  const result = await Contract.deploy(param1, param2, param3);
  await result.deployed();

  console.log(`owner address: ${owner.address}`);
  console.log(`Deployed result address: ${result.address}`);

  const WAIT_BLOCK_CONFIRMATIONS = 6;
  await result.deployTransaction.wait(WAIT_BLOCK_CONFIRMATIONS);

  console.log(`Contract deployed to ${result.address} on ${network.name}`);

  console.log(`Verifying contract on Etherscan...`);

  await run(`verify:verify`, {
    address: result.address,
    constructorArguments: [param1, param2, param3],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
