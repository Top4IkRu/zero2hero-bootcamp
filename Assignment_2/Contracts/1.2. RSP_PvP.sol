// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RSP_game_PvP is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public owner;
    address public constant zeroAddress = 0x0000000000000000000000000000000000000000;
    address public nftContractForFreeFee;

    uint256 public FEEbyBet = 1000; // 1 of 1000000 by bet;
    uint256 public blocksToGameOver = 5 * 60; // 5 minutes

    mapping(address => uint256) public balancePvPbyToken;

    struct Game {
        address token;
        uint256 balance;
        address player_1;
        address player_2;
        address winner;
        uint256 hashChoice_1;
        uint8 choice_2;
        uint256 timeGameOver;
    }
    Game[] public gamesPvP;

    event TransferedOwnership(address indexed fromAddr, address toAddr);
    event FeeChanged(uint256 oldFee, uint256 newFee, address owner);
    event NftContractChanged(address oldNFT, address newNFT, address owner);
    event GamePvPisOpen(address indexed player, address token, uint256 gameIndex);
    event GamePvPisPlayed(address indexed player_1, address indexed player_2, uint256 gameIndex);
    event GamePvPisClosed(address indexed winner, address indexed token, uint256 gameIndex);
    event GamePvPisCancelled(address indexed creator, address indexed token, uint256 gameIndex);

    constructor() payable {
        owner = msg.sender;
     }
    
    modifier checkChoice(uint8 _choice) {
        require(_choice < 3, "Choose rock scissors or paper");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // === Player v Player game === start

    // Вспомогательная функция для создания хэша ключа пользователя
    function createHashForGame(uint8 _choice, uint256 _secretCode) public view checkChoice(_choice) returns(uint256) {
        return uint256(keccak256(abi.encodePacked(_choice, _secretCode, msg.sender)));
    }

    // Получаем первую в списке открытую игру с выбранным токеном PvP
    function getFirstOpenGameByToken(address token) public view returns(bool, uint256) {
        for (uint256 i = 0; i < gamesPvP.length; i++) {
            if (gamesPvP[i].token == token && gamesPvP[i].player_1 != msg.sender && gamesPvP[i].player_2 == zeroAddress) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    // Получаем первую в списке открытую игру с выбранным игроком PvP
    function getOpenGameByCreator(address player) public view returns(bool, uint256) {
        for (uint256 i = 0; i < gamesPvP.length; i++) {
            if (gamesPvP[i].player_1 == player && gamesPvP[i].player_2 == zeroAddress) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    // Создаем открыю игру PvP на BNB
    function createGamePvPbyBNB(uint256 _hashBit) public payable nonReentrant {
        require(msg.value >= 10**14, "Your bet must be greater");
        (bool gameIsReady,) = getOpenGameByCreator(msg.sender);
        require(!gameIsReady, "You have already created game, wait or cancel it");
        gamesPvP.push(Game(
            zeroAddress, 
            msg.value, 
            msg.sender, 
            zeroAddress, 
            zeroAddress, 
            _hashBit, 
            0, 
            (block.timestamp).add(blocksToGameOver) 
        ));
        balancePvPbyToken[zeroAddress] = balancePvPbyToken[zeroAddress].add(msg.value);
        emit GamePvPisOpen(msg.sender, zeroAddress, gamesPvP.length - 1);
    }

    // Создаем открыю игру PvP на пользовательском токене
    function createGamePvPbyToken(address _token, uint256 _amount, uint256 _hashBit) public payable nonReentrant {
        require(_amount >= 0, "Your bet must be greater");
        (bool gameIsReady,) = getOpenGameByCreator(msg.sender);
        require(!gameIsReady, "You have already created game, wait or cancel it");
        require(_checkAllowance(_token, msg.sender, _amount), "This contract does not have approve to spend your token");
        require(_pay(_token, _amount), "Your balance is not enough");
        gamesPvP.push(Game(
            _token, 
            _amount, 
            msg.sender, 
            zeroAddress, 
            zeroAddress, 
            _hashBit, 
            0, 
            (block.timestamp).add(blocksToGameOver)
        ));
        balancePvPbyToken[_token] = balancePvPbyToken[_token].add(_amount);
        emit GamePvPisOpen(msg.sender, _token, gamesPvP.length - 1);
    }

    // Играем в ранее созданную первую в списке открытую игру на BNB
    function playFirstOpenGamePvPbyBNB(uint8 _choice) public payable nonReentrant checkChoice(_choice) {
        (bool _gameIsReady, uint256 _index) = getFirstOpenGameByToken(zeroAddress);
        require(_gameIsReady, "Game is not found");
        _playOpenGame(_choice, _index);
    }

    // Играем в ранее созданную первую в списке открытую игру с пользовательским токеном  
    function playFirstOpenGamePvP(uint8 _choice, address _token) public nonReentrant checkChoice(_choice) {
        (bool _gameIsReady, uint256 _index) = getFirstOpenGameByToken(_token);
        require(_gameIsReady, "Game is not found");
        _playOpenGame(_choice, _index);
    }

    // Играем в ранее созданную первую в списке открытую игру выбранного пользователя  
    function playFirstOpenGameByCreator(uint8 _choice, address _creator) public payable nonReentrant checkChoice(_choice) {
        (bool _gameIsReady, uint256 _index) = getOpenGameByCreator(_creator);
        require(_gameIsReady, "Game is not found");
        _playOpenGame(_choice, _index);
    }

    // Играем в ранее созданную открытую игру по индексу
    function playOpenGameByIndex(uint8 _choice, uint256 _index) public payable nonReentrant checkChoice(_choice) {   
        require(gamesPvP[_index].player_1 != msg.sender
             && gamesPvP[_index].player_2 == zeroAddress, "Game is not found");
            _playOpenGame(_choice, _index);
    }

    // Общая функция для игры по индеску
    function _playOpenGame(uint8 _choice, uint256 _index) internal {
        address _token = gamesPvP[_index].token;
        uint256 _balance= gamesPvP[_index].balance;
        if (_token == zeroAddress) {
            require(msg.value == _balance, "Your balance is not enough");
        } else {
            require(_checkAllowance(_token, msg.sender, _balance), "This contract does not have approve to spend your token");
            require(_pay(_token, _balance), "Your balance is not enough");
        }
        balancePvPbyToken[_token] = balancePvPbyToken[_token].add(_balance);
        gamesPvP[_index].player_2 = msg.sender;
        gamesPvP[_index].choice_2 = _choice;
        gamesPvP[_index].timeGameOver = (block.timestamp).add(blocksToGameOver);
        emit GamePvPisPlayed(gamesPvP[_index].player_1, msg.sender, _index);
    }

    // Получаем индекс сыгранной но не закрытой игры по пользователю
    function getPlayedGame(address player) public view returns(bool, uint256) {
        for (uint256 i = 0; i < gamesPvP.length; i++) {
            if ((gamesPvP[i].player_1 == player || gamesPvP[i].player_2 == player) && gamesPvP[i].player_2 != zeroAddress && gamesPvP[i].winner == zeroAddress) {
                return (gamesPvP[i].player_1 == player, i);
            }
        }
        revert("You are not player or game is not found");
    }

    // Закрываем игру и производим выплату
    function closeGameAndGetMoney(uint8 _choice, uint256 secret) public nonReentrant checkChoice(_choice) {
        (bool isPlayer_1, uint256 i) = getPlayedGame(msg.sender);
        uint256 feeAmount = calculateFee(gamesPvP[i].balance);
        if (isPlayer_1) {
            require(gamesPvP[i].hashChoice_1 == createHashForGame(_choice, secret), "Incorrect data");
            balancePvPbyToken[gamesPvP[i].token] = balancePvPbyToken[gamesPvP[i].token].sub(gamesPvP[i].balance).sub(gamesPvP[i].balance);
            if (_choice == gamesPvP[i].choice_2 || gamesPvP[i].player_1 == gamesPvP[i].player_2){
                gamesPvP[i].winner = address(this);
                uint256 transferAmount = (gamesPvP[i].balance).sub(feeAmount);
                _withdraw(gamesPvP[i].player_1, gamesPvP[i].token, transferAmount); 
                _withdraw(gamesPvP[i].player_2, gamesPvP[i].token, transferAmount);       
            } else if (_choice == 0 && gamesPvP[i].choice_2 == 1
                    || _choice == 1 && gamesPvP[i].choice_2 == 2
                    || _choice == 2 && gamesPvP[i].choice_2 == 0){
                gamesPvP[i].winner = gamesPvP[i].player_1;
                uint256 transferAmount = (gamesPvP[i].balance).mul(2).sub(feeAmount);
                _withdraw(gamesPvP[i].player_1, gamesPvP[i].token, transferAmount);
            } else {
                gamesPvP[i].winner = gamesPvP[i].player_2;
                uint256 transferAmount = (gamesPvP[i].balance).mul(2).sub(feeAmount);
                _withdraw(gamesPvP[i].player_2, gamesPvP[i].token, transferAmount);
            }
        } else {
            require(gamesPvP[i].timeGameOver <= block.timestamp, "Wait until the first player confirms his bet");
            balancePvPbyToken[gamesPvP[i].token] = balancePvPbyToken[gamesPvP[i].token].sub(gamesPvP[i].balance).sub(gamesPvP[i].balance);
            gamesPvP[i].winner = gamesPvP[i].player_2;
            uint256 transferAmount = (gamesPvP[i].balance).mul(2).sub(feeAmount);
            _withdraw(gamesPvP[i].player_2, gamesPvP[i].token, transferAmount);
        }
        emit GamePvPisClosed(gamesPvP[i].winner, gamesPvP[i].token, i); 
    }

    // Отменяем несыгранную игру
    function cancelUnplayedGame() public nonReentrant {
        (bool gameIsReady, uint256 i) = getOpenGameByCreator(msg.sender);
        require(gameIsReady, "You are not player or game is not found");
        require(gamesPvP[i].timeGameOver <= block.timestamp, "Wait until game time is over");
        balancePvPbyToken[gamesPvP[i].token] = balancePvPbyToken[gamesPvP[i].token].sub(gamesPvP[i].balance);
        gamesPvP[i].player_2 = gamesPvP[i].player_1;
        gamesPvP[i].winner = gamesPvP[i].player_1;
        uint256 transferAmount = (gamesPvP[i].balance);
        _withdraw(gamesPvP[i].player_1, gamesPvP[i].token, transferAmount);
        emit GamePvPisCancelled(gamesPvP[i].winner, gamesPvP[i].token, i); 
    }
    // === Player to Player game === end

    // === Only for Owner === start

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        owner = newOwner;
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
    // === Only for Owner === end

    // === Helpers === start
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

    function _checkAllowance(address _tokenAddress, address _tokenOwner, uint256 _amount) private view returns(bool) {
        IERC20 token = IERC20(_tokenAddress);
        return token.allowance(_tokenOwner, address(this)) >= _amount;
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