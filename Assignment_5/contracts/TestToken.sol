// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(address[] memory addresses) ERC20("Test Token", "TT") {
        for (uint i = 0; i < addresses.length; i++) {
            _mint(addresses[i], 10**21);
        }
    }
}
