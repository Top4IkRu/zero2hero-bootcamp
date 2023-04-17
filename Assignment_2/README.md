# Assignment 2

## Contract 1: Rock Scissors Paper (RSP) game

Develop a rock-paper-scissors smart contract. In this smart contract, it should be possible to play for an amount of
0.0001 tBNB. The player can randomly win or lose. When winning, the player can receive a reward up to x2.

EXTRA:

1. Smart contract must use the Oracle blockchain to determine the winner
2. Added multiplayer functionality
3. Adding payment functionality with tokens (ERC20)
4. Add the ability for owners of some NFTs (ERC721) to receive additional. game rewards

### Player-Contract [1.1. RSP_PvC.sol](Contracts/1.1.%20RSP_PvC.sol)

The game supports all EVM wallets that have a BSC testnet connection available (MetaMask, Coinbase, etc.). The player
can play on tBNB and the token. To check the tokens, a cross-comparison of the number of available tokens of the
player's wallet and the contract is carried out using the BSCscan api. The game uses ChainLink to generate random values
that determine the outcome of the game. The game leaves a commission for the game from all players, except for those who
have ZeroCode NFT tokens on their wallet.

### Player-Player [1.2. RSP_PvP.sol](Contracts/1.2.%20RSP_PvP.sol)

The game supports all wallets on the EVM that have a BSC testnet connection (MetaMask, Coinbase, etc.) The player can
play on tBNB and the token. The player has the choice of creating a game or joining another previously created game of
another player. During the game, the player must indicate his unique code, thanks to which the player's choice is hashed
and stored securely in the blockchain. When both players have made their move, the game creator has time to reveal their
move and force the contract to send funds to the winner. If the first player does not want to reveal his move, then the
second player, after a timeout, can end the game and, regardless of the choice of the first player, take all the funds
for himself. This is necessary because the first player transmits a hash of his choice based on a unique code to the
game, and no one except him can know what move he made. If no one has played his game with the player, he can close the
game by timeout and withdraw his funds. The game leaves a commission for the game from all players, except for those who
have ZeroCode NFT tokens on their wallet.

## Contract 2: DocumentSignature

Develop a smart contract “document signature”. Add 2 or more addresses to the white list. Whitelisted addresses can sign
“proposal”.

Result: [2.0. DocumentSignature.sol](Contracts/2.0.%20DocumentSignature.sol)

EXTRA:

1. When signing a document, a unique token is issued (ERC721)
2. Use Merkle Tree to whitelist optimization

## Contract 3: Airdrop

Create a standard ERC20 token. Create a smart contract for airdrop (sending tokens to multiple addresses).
Airdrop your tokens to at least 2 addresses

Result:

1. [3.0. Airdrop.sol](Contracts/3.0.%20Airdrop.sol)
2. [3.1. Airdrop merkle proof.sol](Contracts/3.1.%20Airdrop%20merkle%20proof.sol)

EXTRA:

1. Use Merkle Tree to optimize airdrop (you can do airdrop via claim)

## Contract 4: Voting

Create a contract for the voting system. Add a function to create a new voting session, including a subject and voting
options. Add a feature that allows voters to cast their vote for a particular option. Add a function to get the current
vote count for each option. Add a function to get a list of all voting sessions. Add a function to retrieve the results
of a particular voting session.

Result: [4.0 Voting.sol](Contracts/4.0%20Voting.sol)

EXTRA:

1. Add a feature that allows the creator of a voting session to set a minimum quorum for results to be considered
   valid.
2. Add Digital Identity functionality to prevent sibyl attacks

## Contract 5: NFT

Write simple NFT contract

[5.0. NFT.sol](Contracts/5.0.%20NFT.sol)