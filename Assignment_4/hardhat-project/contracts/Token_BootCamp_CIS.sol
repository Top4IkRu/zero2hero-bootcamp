// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract T0xC is ERC20, IERC721Receiver, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 constant public STAKING_REWARD = 1 * 10 ** 18;
    uint256 constant public ACCRUAL_PERIOD = 60 * 10; // 10 min
    uint256 constant public BURN_FEE = 5; // 0.05%
    uint256 constant public FIRST_MINT_REWARD = 720 * 10 ** 18;

    IERC721 public _nftCollection;
    mapping(uint256 => uint256) public _lastStakeTime;
    mapping(uint256 => address) public _owners;
    mapping(uint256 => bool) public _isFirstStaked;

    event Received(address indexed, uint256);

    constructor(address nftCollectionAddress) ERC20("Token by 0xc0de", "T0xC") {
        _nftCollection = IERC721(nftCollectionAddress);
    }

    function stake(uint256 tokenId) public nonReentrant {
        require(_nftCollection.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        _lastStakeTime[tokenId] = block.timestamp;
        _owners[tokenId] = msg.sender;
        _nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);
        if (!_isFirstStaked[tokenId]) {
            _isFirstStaked[tokenId] = true;
            _mint(msg.sender, FIRST_MINT_REWARD);
        }
    }

    function unstake(uint256 tokenId) public nonReentrant {
        require(_nftCollection.ownerOf(tokenId) == address(this), "Contract doesn't own this NFT");
        require(_owners[tokenId] == msg.sender, "You don't own this NFT");
        _nftCollection.safeTransferFrom(address(this), msg.sender, tokenId);
        _owners[tokenId] = address(0);
        uint256 reward = _calculateReward(tokenId);
        _mint(msg.sender, reward);
    }

    function _calculateReward(uint256 tokenId) private view returns (uint256) {
        uint256 elapsed = block.timestamp.sub(_lastStakeTime[tokenId]);
        return elapsed.mul(STAKING_REWARD).div(ACCRUAL_PERIOD);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        return transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        if (_nftCollection.balanceOf(sender) > 0 || _nftCollection.balanceOf(recipient) > 0) {
            _transfer(sender, recipient, amount);
        } else {
            uint256 burnAmount = calculateFee(amount);
            _burn(sender, burnAmount);
            uint256 transferAmount = amount.sub(burnAmount);
            _transfer(sender, recipient, transferAmount);
        }
        return true;
    }

    function calculateFee(uint256 amount) public pure returns (uint256) {
        return amount.mul(BURN_FEE).div(10000);
    }

    function setNftCollectionAddress(address _address) public onlyOwner {
        _nftCollection = IERC721(_address);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdraw() external onlyOwner {
        (bool success,) = _msgSender().call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }

    function withdrawTokens(address _address) external onlyOwner {
        IERC20 token = IERC20(_address);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(_msgSender(), balance);
    }

    receive() external payable {
        emit Received(_msgSender(), msg.value);
    }
}