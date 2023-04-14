require("dotenv").config();
const { ethers } = require("ethers");
const { CONTRACT_ADDRESS, ABI, ERC20_ABI } = require("./constantsForNode");
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BNBT_RPC_URL = process.env.BNBT_RPC_URL;

const provider = new ethers.providers.JsonRpcProvider(BNBT_RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);
const addressSigner = signer.address;
console.error(`Address signer: ${addressSigner}`);

const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, signer);
const WAIT_BLOCK_CONFIRMATIONS = 2;

// Функция минта токенов. Автоматически проверяется минимальное требуемое количество для минта
async function safeMint(address) {
  const price = await contract.priceToMint(address);
  const tx = await contract.safeMint({ value: price });
  console.log(`safeMint hash: ${tx.hash}`);
  await signer.provider.waitForTransaction(tx.hash, WAIT_BLOCK_CONFIRMATIONS);
}

// Донат в Коине блокчейна ВНИМАНИЕ, функция принимает значение кратное 10**18, то есть единице Ether
async function donateEthByEther(author, valueFromEther) {
  const value = ethers.utils.parseEther(valueFromEther.toString());
  const tx = await contract.donateEth(author, { value: value });
  console.log(`donate hash: ${tx.hash}`);
}

// Получить список адресов токенов для доната по автору
async function donateTokenAddressesByAuthor(author) {
  let addresses = [];
  let counter = 0;
  while (counter < 999) {
    try {
      const addr = await contract.donateTokenAddressesByAuthor(
        author,
        counter++
      );
      addresses.push(addr);
    } catch (err) {
      // console.log(`Ошибка при получении адреса с индексом ${counter - 1}: ${err}`);
      break;
    }
  }
  return addresses;
}

// Донат в Токенах ВНИМАНИЕ, функция принимает значение кратное 10**18, то есть единице Ether
async function donateTokenByEther(tokenAddress, tokenAmountFromEther, author) {
  const value = ethers.utils.parseEther(tokenAmountFromEther.toString());
  const contractERC20 = new ethers.Contract(tokenAddress, ERC20_ABI, signer);
  const allowance = await contractERC20.allowance(
    addressSigner,
    CONTRACT_ADDRESS
  );
  const balance = await contractERC20.balanceOf(addressSigner);
  if (balance < value) {
    return {
      message: "Balance to low for donate",
    };
  }
  if (allowance < value) {
    const approveTx = await contractERC20.approve(CONTRACT_ADDRESS, balance);
    console.log(`approve hash: ${approveTx.hash}`);
    await signer.provider.waitForTransaction(
      approveTx.hash,
      WAIT_BLOCK_CONFIRMATIONS
    );
  }
  const tx = await contract.donateToken(tokenAddress, value, author);
  console.log(`donateToken hash: ${tx.hash}`);
  return {
    message: "Donation requested",
  };
}

// Получение токенов пользователя, возвращает количество токенов и их id
async function getUsersTokens(address) {
  const balance = await contract.balanceOf(address);
  let tokens = [];
  if (balance > 0) {
    const totalSupply = await contract.totalSupply();
    for (let tokenId = 0; tokenId < totalSupply; tokenId++) {
      const owner = await contract.ownerOf(tokenId);
      if (owner.toLowerCase() === address.toLowerCase()) {
        tokens.push(tokenId);
      }
      if (tokens.length >= balance) {
        break;
      }
    }
  }
  return {
    balance: tokens.length,
    tokens: tokens,
  };
}

async function main() {
  let usersToken = await getUsersTokens(addressSigner);
  console.log(
    `User token balance: ${usersToken.balance}, tokens: ${usersToken.tokens}`
  );
  if (usersToken.balance == 0) {
    await safeMint(addressSigner);
  }

  // await donateEthByEther(usersToken.tokens[0], 0.0282828);

  const donateToken0 = await donateTokenAddressesByAuthor(0);
  console.log(
    `Author id: 0 has ${donateToken0.length} addresses to donate: ${donateToken0}`
  );

  const donateToken1 = await donateTokenAddressesByAuthor(1);
  console.log(
    `Author id: 1 has ${donateToken1.length} addresses to donate: ${donateToken1}`
  );

  if (donateToken0.length > 0) {
    const donationResult = await donateTokenByEther(donateToken0[0], 100, 0);
    console.log(`Donation result: ${donationResult.message}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
