// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ZeroCode is ERC20 {
    using SafeMath for uint256;
    bool airdropIsOver;
    address public owner;
    uint256 public constant FEE_PERCENT = 10;
    uint256 public totalFeesBurned;

    modifier onlyOwner{
        require(msg.sender == owner, "Only owner!");
        _;
    }

    constructor() ERC20("ZeroCode", "0xC") {
        owner = msg.sender;
        uint256 initialSupply = 1_000_000 * 10 ** decimals();
        _mint(address(this), initialSupply);
        airdropIsOver = false;
    }

    function airdrop(address[] memory accounts) public onlyOwner {
        require(!airdropIsOver, "Airdrop is over");
        require(balanceOf(address(this)) > 0, "Insufficient balance for airdrop");
        uint256 amount = balanceOf(address(this)).div(accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            _transfer(address(this), accounts[i], amount);
        }
        if (balanceOf(address(this)) > 0) {
            totalFeesBurned = totalFeesBurned.add(balanceOf(address(this)));
            _burn(address(this), balanceOf(address(this)));
        }
        airdropIsOver = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 feeAmount = calculateFee(amount);
        uint256 transferAmount = amount.sub(feeAmount);

        super.transfer(recipient, transferAmount);
        totalFeesBurned = totalFeesBurned.add(feeAmount);
        _burn(msg.sender, feeAmount);

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 feeAmount = calculateFee(amount);
        uint256 transferAmount = amount.sub(feeAmount);

        super.transferFrom(sender, recipient, transferAmount);
        super.transferFrom(sender, owner, feeAmount);

        return true;
    }

    function calculateFee(uint256 amount) public pure returns (uint256) {
        return amount.mul(FEE_PERCENT).div(100);
    }

    function transferOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
}