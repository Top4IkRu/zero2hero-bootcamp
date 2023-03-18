// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; 
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ERC20Airdroper {
    using SafeERC20 for IERC20Metadata;
    using SafeMath for uint256;

    struct AirdropTicker {
        address dropToken;
        bytes32 merkleRoot;
        uint256 airdropAmount;
        uint256 airdroppedValue;
    }

    AirdropTicker[] public airdropTickers;
    mapping(address => mapping(address => bool)) hasClaimed;

    event Airdrop(address indexed recipient, address indexed token, uint256 amount);
    event NewAirdropCreated(address indexed token, uint256 amount);

    constructor() {
    }

    function makeAirdrop(address _token, bytes32 _merkleRoot, uint256 _amount, uint256 _countOfAddress) public {
        IERC20Metadata token = IERC20Metadata(_token);
        uint256 dropAmount = _amount.mul(_countOfAddress);
        require(token.balanceOf(msg.sender) >= dropAmount, "Not enough tokens to airdrop");
        token.safeTransferFrom(
            msg.sender,
            address(this),
            dropAmount
        );

        airdropTickers.push(AirdropTicker({dropToken: _token,merkleRoot: _merkleRoot,airdropAmount: _amount,airdroppedValue: 0}));
        emit NewAirdropCreated(_token, dropAmount);
    }

    function claim(address _token, bytes32[] calldata _proof) public {
        require(!hasClaimed[_token][msg.sender], "Already claimed");
        (, bytes32 _merkleRoot, uint256 _airdropAmount, uint256 _airdroppedValue) = getAirdropTicker(_token);
        require(checkMerkleProof(_merkleRoot, _proof), "Invalid proof");

        hasClaimed[_token][msg.sender] = true;
        _airdroppedValue = _airdroppedValue.add(_airdropAmount);

        IERC20Metadata token = IERC20Metadata(_token);
        token.safeTransfer(msg.sender, _airdropAmount);

        emit Airdrop(msg.sender, _token, _airdropAmount);
    }

    function checkMerkleProof(bytes32 _merkleRoot, bytes32[] calldata _proof) public view returns(bool){
        bytes32 _leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, 0))));
        return MerkleProof.verify(_proof, _merkleRoot, _leaf);
    }

    function getAirdropTicker(address _token) public view returns (address, bytes32, uint256, uint256) {
        for (uint256 i = 0; i < airdropTickers.length; i++) {
            if (airdropTickers[i].dropToken == _token) {
                return (airdropTickers[i].dropToken, airdropTickers[i].merkleRoot, airdropTickers[i].airdropAmount, airdropTickers[i].airdroppedValue);
            }
        }
        revert("Airdrop ticker not found");
    }
}