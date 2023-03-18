// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is ERC721 {
    address public owner;
    uint256 public constant MAX_TOKENS = 15;
    string public baseURI;

    modifier onlyOwner{
        require(msg.sender == owner, "Only owner!");
        _;
    }

    constructor(string memory _baseURI) ERC721("ZeroCodeNFT", "0xc0de") {
        owner = msg.sender;
        baseURI = _baseURI;
        for (uint256 i = 0; i < MAX_TOKENS; i++) {
            _safeMint(msg.sender, i);
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory uriNumber = Strings.toString(tokenId);
        return string.concat(baseURI, uriNumber, ".json");
    }
}