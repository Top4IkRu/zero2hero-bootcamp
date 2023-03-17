// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RSP_game is ReentrancyGuard, VRFConsumerBaseV2, ConfirmedOwner {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    VRFCoordinatorV2Interface COORDINATOR;

    uint16 internal requestConfirmations = 3;
    uint32 internal callbackGasLimit = 250000;
    uint32 internal numWords = 1;
    uint64 internal s_subscriptionId = 2714;
    address internal constant vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
    bytes32 internal constant keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;

    address public constant zeroAddress = 0x0000000000000000000000000000000000000000;
    address public nftContractForFreeFee;

    uint256 public FEEbyBet = 1000; // 1 of 1000000 by bet;

    struct GameSolo {
        bool isPlayed;
        uint8 choice;
        address player;
        address token;
        uint256 balance;
    }
    mapping(uint256 => GameSolo) public commitments;

    event GamePvCisPlayed(address indexed player, uint256 amount, uint8 playerChoice, uint8 contractChoice, string result);
    event TransferedOwnership(address indexed fromAddr, address toAddr);
    event FeeChanged(uint256 oldFee, uint256 newFee, address owner);
    event NftContractChanged(address oldNFT, address newNFT, address owner);

    constructor()
    VRFConsumerBaseV2(0x6A2AAd07396B36Fe02a22b33cf443582f682c82f)
    ConfirmedOwner(msg.sender)
    payable {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x6A2AAd07396B36Fe02a22b33cf443582f682c82f
        );
    }
    
    modifier checkChoice(uint8 _choice) {
        require(_choice < 3, "Choose rock scissors or paper");
        _;
    }

    // === Player to Contract game === start

    // Создание игры с контрактом на BNB
    function playPvCbyBNB(uint8 _choice) public payable nonReentrant checkChoice(_choice) returns (uint256){
        require(msg.value <= maxBetPvCbyBNB(), "Balance is not enough");
        require(msg.value >= 10**14, "Your bet must be greater");

        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        commitments[requestId] = GameSolo(false, _choice, msg.sender, zeroAddress, msg.value);
        return requestId;
    }
    
    // Создание игры с контрактом на пользовательский токен
    function playPvCbyToken(uint8 _choice, address _token, uint256 _amount) public nonReentrant checkChoice(_choice) returns (uint256){
        require(_amount <= maxBetPvCbyToken(_token), "Your bet should be less than contract balance");
        require(_pay(_token, _amount), "Your balance is not enough");
        require(_checkAllowance(_token, msg.sender, _amount), "This contract does not have approve to spend your token");

        uint256 requestId = COORDINATOR.requestRandomWords(keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        commitments[requestId] = GameSolo(false, _choice, msg.sender, _token, _amount);
        return requestId;
    }

    // Колбэк chainlink со случайным значением, определение победитя игры с контрактом
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        GameSolo storage game = commitments[_requestId];
        require(!game.isPlayed, "Game is played");
        game.isPlayed = true;
        uint8 contractChoice = uint8(_randomWords[0] % 3);
        string memory result;

        uint256 feeAmount = calculateFee(game.balance);
        if (contractChoice == game.choice) {
            uint256 transferAmount = (game.balance).sub(feeAmount);
            _withdraw(game.player, game.token, transferAmount);
            result = "Draw";
        } else if (game.choice == 0 && contractChoice == 1
                || game.choice == 1 && contractChoice == 2
                || game.choice == 2 && contractChoice == 0){
            uint256 transferAmount = (game.balance.mul(2)).sub(feeAmount);
            _withdraw(game.player, game.token, transferAmount);
            result = "Win";
        } else {
            result = "Fail";
        }
        emit GamePvCisPlayed(game.player, game.balance, game.choice, contractChoice, result);
    }
    // === Player to Contract game === end

    // === Only for SuperUser === start
    
    function setNewOptionsForVRF(
        uint16 _requestConfirmations, 
        uint32 _callbackGasLimit,
        uint32 _numWords,
        uint64 _s_subscriptionId
        ) public onlyOwner {
            require(_requestConfirmations >= 3, "Bad requestConfirmations");
            require(_callbackGasLimit >= 200000, "Bad callbackGasLimit");
            require(_numWords > 0, "Bad numWords");
            require(_s_subscriptionId > 0, "Bad s_subscriptionId");
            requestConfirmations = _requestConfirmations;
            callbackGasLimit = _callbackGasLimit;
            numWords = _numWords;
            s_subscriptionId = _s_subscriptionId;
    }

    function setFee(uint256 _fee) public onlyOwner {
        emit FeeChanged (FEEbyBet, _fee, msg.sender);
        FEEbyBet = _fee;
    }

    function setNftContractForFreeFee(address _address) public onlyOwner {
        emit NftContractChanged(nftContractForFreeFee, _address, msg.sender);
        nftContractForFreeFee = _address;
    }

    function transferOwner (address newAddress) public onlyOwner {
        require(!_isContract(newAddress), "Contract cannot be the Owner");
        emit TransferedOwnership(msg.sender, newAddress);
    }

    function withdraw() public onlyOwner {
        _withdraw(msg.sender, zeroAddress, address(this).balance);
    }

    function withdrawTokens(address _token) public onlyOwner nonReentrant {
        IERC20 token = IERC20(_token);
        require(token.balanceOf(address(this)) > 0, "Balance is too small for withdrawal");
        _withdraw(msg.sender, _token, token.balanceOf(address(this)));
    }
    // === Only for SuperUser === end

    // === Helpers === start
    function maxBetPvCbyBNB() public view returns(uint256) {
        return address(this).balance;
    }

    function maxBetPvCbyToken(address _token) public view returns(uint256) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(address(this));
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        return _isERC721(nftContractForFreeFee) && IERC721(nftContractForFreeFee).balanceOf(msg.sender) > 0 ? 
            0 : amount.mul(FEEbyBet).div(1000000);
    }

    function _pay(address _tokenAddr, uint256 _amount) private returns(bool) {
        IERC20 token = IERC20(_tokenAddr);
        return token.transferFrom(msg.sender, address(this), _amount);
    }

    function _withdraw(address _to, address _tokenAddr, uint256 _amount) private returns(bool) {
        if (_tokenAddr == zeroAddress){
            (bool success,) = _to.call{value: _amount}("");
            return success;
        } else {
            IERC20 token = IERC20(_tokenAddr);
            return token.transfer(_to, _amount);
        }
    }

    function _isERC721(address _contract) private view returns (bool) {
        bytes4 interfaceId = bytes4(keccak256("supportsInterface(bytes4)"));
        bytes4 erc721Id = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
        (bool success, bytes memory result) = _contract.staticcall(abi.encodeWithSelector(interfaceId, erc721Id));
        return success && result.length > 0 && abi.decode(result, (bool));
    }

    function _checkAllowance(address tokenAddress, address owner, uint256 amount) private view returns(bool) {
        IERC20 token = IERC20(tokenAddress);
        return token.allowance(owner, address(this)) >= amount;
    }
    
    function _isContract(address addr) private view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    // === Helpers === end

    receive() external payable {

    }
}