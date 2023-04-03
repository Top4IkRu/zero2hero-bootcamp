// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT0xC0de is ERC721Enumerable, IERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    uint64 public royaltyFee = 500;
    uint256 public MAX_SUPPLY = 200;
    uint256 public COUNT_OF_IMAGES = 20;
    uint256 publicSaleTokenPrice = 0.001 ether;
    string public baseURI;
    mapping(address => bool) public addressMinted;

    event NewMint(address indexed, uint256);
    event Received(address indexed, uint256);

    constructor(string memory _baseURI) ERC721("Students of 0xc0de", "NFT0xC0de") {
        baseURI = _baseURI;
        _safeMint(msg.sender, 0);
    }

    function setBaseURI(uint256 _count, string memory _baseURI) public onlyOwner {
        COUNT_OF_IMAGES = _count;
        baseURI = _baseURI;
    }

    function setMaxSupply(uint256 _value) public onlyOwner {
        require(_value >= totalSupply(), "Cannot set greater less then total supply");
        MAX_SUPPLY = _value;
    }

    function safeMint() public nonReentrant payable {
        require(!addressMinted[msg.sender], "Mint is not available for you");
        require(publicSaleTokenPrice <= msg.value, "Ether value sent is not correct");
        uint256 _currentSupply = totalSupply();
        require(_currentSupply < MAX_SUPPLY, "You reached max supply");
        addressMinted[msg.sender] = true;
        emit NewMint(msg.sender, _currentSupply);
        _safeMint(msg.sender, _currentSupply);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        uint256 uriNumber = tokenId % COUNT_OF_IMAGES;
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, uriNumber.toString(), ".json"))
                : "";
    }

    /** Royalty **/
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId), "query for nonexistent token");
        return (address(this), (salePrice * royaltyFee) / 10000);
    }

    function setRoyaltyFee(uint64 fee) external onlyOwner {
        require(fee <= 5000, "fee is too high");
        royaltyFee = fee;
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