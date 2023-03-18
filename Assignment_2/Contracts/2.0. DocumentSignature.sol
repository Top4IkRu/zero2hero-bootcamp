// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract DocumentSignature is ERC721, ReentrancyGuard {

    struct Proposal {
        bool signed;
        address creator;
        address signatory;
        uint256 amount;
        string documentLink;
    }

    bytes32 public merkleRoot;
    Proposal[] public proposals;

    address constant zeroAddress = 0x0000000000000000000000000000000000000000;

    event CreatedProposal(address indexed, string documentLink, uint256 price);
    event ProposalIsSigned(address indexed, string documentLink);

    constructor(bytes32 _merkleRoot) ERC721("Document Signature", "DocSig") {
        merkleRoot = _merkleRoot;
    }

    function checkMerkleProof(bytes32[] calldata proof) public view returns(bool){
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, 0))));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function createProposal(string memory _documentLink) public payable {
        require(msg.value >= 10**15, "Your offer should be more than 0.001 BNB");
        proposals.push(Proposal({signed: false, creator: msg.sender, signatory: zeroAddress, documentLink: _documentLink, amount: msg.value}));
        emit CreatedProposal(msg.sender, _documentLink, msg.value);
    }

    function signByIndex(uint256 index, bytes32[] calldata proof) public {
        require(!isSigned(index), "Already signed");
        require(checkMerkleProof(proof), "Invalid proof");
        proposals[index].signed = true;
        proposals[index].signatory = msg.sender;
        _safeMint(proposals[index].creator, index);
        emit ProposalIsSigned(proposals[index].creator, proposals[index].documentLink);
        withdraw(proposals[index].amount);
    }

    function signLastUnsigned(bytes32[] calldata proof) public {
        uint256 index = getIndexOfLastUnsigned();
        signByIndex(index, proof);
    }

    function getIndexOfLastUnsigned() public view returns(uint256) {
        for (uint256 i = 0; i < proposals.length; i++) {
            if (!isSigned(i)) {
                return i;
            }
        }
        revert("Unsigned proposal not found");
    }

    function isSigned(uint256 index) public view returns (bool) {
        return proposals[index].signed;
    }

    function tokenURI(uint256 index) public view virtual override returns (string memory) {
        require(_exists(index), "query for nonexistent token");
        return proposals[index].documentLink;
    }

    function withdraw(uint256 amount) internal nonReentrant {
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success, "withdraw failed");
    }

    receive() external payable {
        
    }
}