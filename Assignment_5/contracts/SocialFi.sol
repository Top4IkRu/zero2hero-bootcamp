// SPDX-License-Identifier: MIT
/************************************************************\
*                                                            *
*      ██████╗ ██╗  ██╗ ██████╗ ██████╗ ██████╗ ███████╗     *
*     ██╔═████╗╚██╗██╔╝██╔════╝██╔═████╗██╔══██╗██╔════╝     *
*     ██║██╔██║ ╚███╔╝ ██║     ██║██╔██║██║  ██║█████╗       *
*     ████╔╝██║ ██╔██╗ ██║     ████╔╝██║██║  ██║██╔══╝       *
*     ╚██████╔╝██╔╝ ██╗╚██████╗╚██████╔╝██████╔╝███████╗     *
*      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝     *
*                                                            *
\************************************************************/                                                  

pragma solidity ^0.8.18;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract SocialFi is ERC721Enumerable, IERC2981, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;

    uint8 public levels; // Количество уровней рейтинга авторов
    uint16 public royaltyFee = 1000; // Рояльти за продажу NFT
    uint256 public totalAmounts; // Общая сумма оплат в Eth, прошедшая через контракт, используется для определения рейтинга авторов
    uint256 publicSaleTokenPrice = 0.1 ether; // Цена создания нового NFT (нового канала)
    string public baseURI; // Базовая ссылка на папку с метаданными NFT
    mapping (uint256 => uint256) public authorsAmounts; // Сумма оплаты по каждому автору (каналу), прошедшая через контракт
    IUniswapV2Router02 public uniswapRouter; // Провайдер для перерасчета платы в токенах на Eth

    // Типы сессий
    enum Types {
        notModerated,
        moderated
    }

    // Списки участников
    struct Participants {
        address[] confirmed;
        address[] notConfirmed;
        address[] rejected;
    }

    // Рейтинг сессий
    struct Rating {
        uint256 like;
        uint256 dislike;
    }

    // Структура сессий
    struct Session {
        address tokenAddress;
        uint256 price;
        uint256 expirationTime;
        uint256 maxParticipants;
        string name;
        Types typeOf;
        Participants participants;
        Rating rating;
    }

    mapping(uint256 => address) public managers; // Менеджер канала, который является валидатором на сессиях
    mapping(uint256 => address[]) public donateTokenAddressesByAuthor; // Разрешённые токены для доната
    mapping(uint256 => mapping(address => bool)) public whiteListByAuthor; // Белый список автора
    mapping(uint256 => mapping(address => bool)) public blackListByAuthor; // Черный список автора
    mapping(uint256 => Session[]) public sessionByAuthor; // Сессии автора
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public participantVoted; // Списки проголосовавших пользователей
    mapping(address => uint256) internal blockedForWithdraw; // Сердства пользователей, заблокированные на контракте

    event Received(address indexed sender, uint256 value);
    event NewSessionCreated(uint256 indexed author, string name, address token, uint256 price, uint256 expirationTime, uint256 maxParticipants, Types typeOf);
    event Donate(address indexed sender, address indexed token, uint256 value, uint256 indexed author);
    event AwaitingConfirmation(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event PurchaseConfirmed(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event PurchaseRejected(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event PurchaseCanceled(address indexed participant, uint256 indexed author, uint256 indexed sessionId);
    event NewVote(bool isLike, address indexed participant, uint256 indexed author, uint256 indexed sessionId);

    modifier supportsERC20(address _address){
        require(
            _address == address(0) || IERC20(_address).totalSupply() > 0 && IERC20(_address).allowance(_address, _address) >= 0,
            "Is not ERC20"
        );
        _;
    }

    modifier onlyAuthor(uint256 author){
        require(ownerOf(author) == msg.sender || managers[author] == msg.sender , "Only author");
        _;
    }
    
    modifier sessionIsOpenForSender(uint256 author, uint256 sessionId){
        require(!blackListByAuthor[author][msg.sender], "You blacklisted");
        Session memory session = sessionByAuthor[author][sessionId];
        require(session.expirationTime > block.timestamp && session.participants.confirmed.length < session.maxParticipants, "Session is closed");
        Participants memory participants = session.participants;
        require(!isAddressExist(msg.sender, participants.rejected), "You denied");
        require(!isAddressExist(msg.sender, participants.notConfirmed), "Expect decision on your candidacy");
        require(!isAddressExist(msg.sender, participants.confirmed), "You already on list");
        _;
    }

    constructor(address _uniswapRouterAddress, uint8 _levelsCount, string memory _baseURI) ERC721("SocialFi by 0xc0de", "SoFi") {
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
        levels = _levelsCount;
        baseURI = _baseURI;
    }

    /***************Common interfaces BGN***************/
    // Установить новый uri для NFT
    function setBaseURI(uint8 _levelsCount, string memory _baseURI) external onlyOwner {
        levels = _levelsCount;
        baseURI = _baseURI;
    }

    // Установить новую цену для минта NFT
    function setPublicSaleTokenPrice(uint256 _newPrice) external onlyOwner {
        publicSaleTokenPrice = _newPrice;
    }

    // Установить адрес нового провайдера для перевода стоимости токена в базовый коин
    function setNewRouter(address _uniswapRouterAddress) external onlyOwner {
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
    }

    function priceToMint(address minter) public view returns(uint256){
        uint256 balance = balanceOf(minter);
        return publicSaleTokenPrice * (2 ** balance);
    }

    // Создать нового автора (то есть минт NFT)
    function safeMint() public nonReentrant payable {
        require(priceToMint(msg.sender) <= msg.value, "Low value");
        (bool success, ) = owner().call{value: msg.value}("");
        require(success, "fail");
        uint256 nextIndex = totalSupply();
        addAuthorsRating(msg.value, nextIndex);
        _safeMint(msg.sender, nextIndex);
    }

    // Получить uri метаданных NFT по id токена
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        uint256 thisLevel = (10 ** levels) * authorsAmounts[tokenId] / totalAmounts;
        uint256 uriNumber = myLog10(thisLevel);
        if (uriNumber >= levels){
            uriNumber = levels - 1;
        }
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, uriNumber.toString(), ".json"))
                : "";
    }

    // Вспомогательная функция подсчета логорифма
    function myLog10(uint256 x) internal pure returns (uint256) {
        uint256 result = 0;
        while (x >= 10){
            x /= 10;
            result += 1;
        }
        return result;
    }

    // Вызывается в случае отправки на контракт средств без вызова иных функций
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    /***************Common interfaces END***************/

    /***************Author options BGN***************/
    function addAuthorsRating(uint256 value, uint256 author) private {
        totalAmounts += value;
        authorsAmounts[author] += value;
    }

    // Установить менеджера для автора, может только владелец NFT
    function setManager(address newManager, uint256 author) public {
        require(ownerOf(author) == msg.sender, "Only owner");
        managers[author] = newManager;
    }

    // Добавить адрес контракта токена для донатов
    function addDonateAddress(address tokenAddress, uint256 author) supportsERC20(tokenAddress) onlyAuthor(author) public {
        address[] storage tokens = donateTokenAddressesByAuthor[author];
        require(!isAddressExist(tokenAddress, tokens), "Already exists");
        tokens.push(tokenAddress);
    }

    // Удалить адрес контракта токенов для донатов 
    function removeDonateAddress(address tokenAddress, uint256 author) supportsERC20(tokenAddress) onlyAuthor(author) public {
        address[] storage tokens = donateTokenAddressesByAuthor[author];
        require(isAddressExist(tokenAddress, tokens), "Not exist");
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenAddress) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    // Проверка наличия указанного адреса в указанной коллекции адресов
    function isAddressExist(address _addressToCheck, address[] memory _collection) public pure returns (bool) {
        for (uint i = 0; i < _collection.length; i++) {
            if (_collection[i] == _addressToCheck) {
                return true;
            }
        }
        return false;
    }

    // Создание новой сессии с оплатой в базовом коине
    function createNewSessionByEth(
        uint256 author, 
        uint256 price, 
        uint256 expirationTime, 
        uint256 maxParticipants, 
        Types typeOf, 
        string memory name) onlyAuthor(author) public{
            require(price >= 10**6, "Low price");
            createNewSessionByToken(author, address(0), price, expirationTime, maxParticipants, typeOf, name);
        }

    // Создание новой сессии с оплатой в указанных токенах (осуществляется проверка на реализацию интерфеса IERC20)
    function createNewSessionByToken(
        uint256 author, 
        address tokenAddress, 
        uint256 price, 
        uint256 expirationTime, 
        uint256 maxParticipants, 
        Types typeOf, 
        string memory name) supportsERC20(tokenAddress) onlyAuthor(author) public{
        require(price > 0, "Low price");
        Rating memory rating = Rating(0, 0);  
        Participants memory participants = Participants(
            new address[](0),
            new address[](0),
            new address[](0)
        );        
        Session memory session = Session ({
            tokenAddress: tokenAddress,
            price: price,
            expirationTime: expirationTime,
            maxParticipants: maxParticipants,
            name: name,
            typeOf: typeOf,
            participants: participants,
            rating: rating
        });
        sessionByAuthor[author].push(session);
        emit NewSessionCreated(author, name, tokenAddress, price, expirationTime, maxParticipants, typeOf);
    }

    // Добавить адрес в белый список
    function addToWhiteList(address user, uint256 author) onlyAuthor(author) public {
        blackListByAuthor[author][user] = false;
        whiteListByAuthor[author][user] = true;
    }

    // Исключить адрес из белого списка
    function removeWhiteList(address user, uint256 author) onlyAuthor(author) public {
        whiteListByAuthor[author][user] = false;
    }

    // Добавить адрес в чёрный список
    function addToBlackList(address user, uint256 author) onlyAuthor(author) public {
        whiteListByAuthor[author][user] = false;
        blackListByAuthor[author][user] = true;
    }

    // Исключить адрес из чёрного списка
    function removeBlackList(address user, uint256 author) onlyAuthor(author) public {
        blackListByAuthor[author][user] = false;
    }

    // Подтвердить заявку участника сессии с последующим проведением оплаты
    function confirmParticipants(address participant, uint256 author, uint256 sessionId) onlyAuthor(author) public returns(bool) {
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        require(isAddressExist(participant, participants.notConfirmed), "Is denied");
        address[] storage notConfirmed = participants.notConfirmed;
        for (uint i = 0; i < notConfirmed.length; i++) {
            if (notConfirmed[i] == participant) {
                notConfirmed[i] = notConfirmed[notConfirmed.length - 1];
                notConfirmed.pop();
                participants.confirmed.push(participant);
                unblockAndPay(session.tokenAddress, session.price, author);
                emit PurchaseConfirmed(participant, author, sessionId);
                return true;
            }
        }
        return false;
    }

    // Отказать участнику в регистрации на сессиию с последующим возвратом средств участнику
    function unconfirmParticipants(address participant, uint256 author, uint256 sessionId) onlyAuthor(author) public returns(bool) {
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        require(isAddressExist(participant, participants.notConfirmed), "Is denied");
        address[] storage notConfirmed = participants.notConfirmed;
        for (uint i = 0; i < notConfirmed.length; i++) {
            if (notConfirmed[i] == participant) {
                notConfirmed[i] = notConfirmed[notConfirmed.length - 1];
                notConfirmed.pop();
                participants.rejected.push(participant);
                unblockAndReject(participant, session.tokenAddress, session.price);
                emit PurchaseRejected(participant, author, sessionId);
                return true;
            }
        }
        return false;
    }

    // Вспомогательная функция для проведения оплаты, confirmParticipants
    function unblockAndPay(address tokenAddress, uint256 tokenAmount, uint256 author) internal {
        if (tokenAddress == address(0)){
            paymentEth(author, tokenAmount);
        } else {
            paymentToken(address(this), tokenAddress, tokenAmount, author);
        }
        blockedForWithdraw[tokenAddress] -= tokenAmount;
    }

    // Вспомогательная функция для возврата средств участнику, unconfirmParticipants и cancelByParticipant
    function unblockAndReject(address participant, address tokenAddress, uint256 tokenAmount) internal nonReentrant {
        if (tokenAddress == address(0)){
            (bool success, ) = participant.call{value: tokenAmount}("");
            require(success, "fail");
        } else {
            IERC20 token = IERC20(tokenAddress);
            uint256 contractBalance = token.balanceOf(address(this));
            if (contractBalance < tokenAmount){
                tokenAmount = contractBalance;
            }
            token.transfer(participant, tokenAmount);
        }
        blockedForWithdraw[tokenAddress] -= tokenAmount;
    }

    // Вспомогательная функция расчета комиссии контракта в зависимости от уровня автора (зависит от количества средств, которые автор заработал)
    function contractFeeForAuthor(uint256 author, uint256 amount) public view returns(uint256){
        uint256 thisLevel = (10 ** levels) * authorsAmounts[author] / totalAmounts;
        return amount * 2 / ( 100 * (2 ** myLog10(thisLevel)));
    }
    /***************Author options END***************/

    /***************User interfaces BGN***************/
    // Вспомогательная функция проведения оплат в базовом коине с учётом комиссий
    function paymentEth(uint256 author, uint256 value) internal nonReentrant {
        uint256 contractFee = contractFeeForAuthor(author, value);
        uint256 amount = value - contractFee;
        (bool success1, ) = owner().call{value: contractFee}("");
        (bool success2, ) = ownerOf(author).call{value: amount}("");
        require(success1 && success2, "fail");
        addAuthorsRating(value, author);
    }

    // Вспомогательная функция проведения оплат в токенах с учётом комиссий
    function paymentToken(address sender, address tokenAddress, uint256 tokenAmount, uint256 author) internal nonReentrant {
        address[] memory tokensByAuthor = donateTokenAddressesByAuthor[author];
        require(isAddressExist(tokenAddress, tokensByAuthor), "Token not exist");

        IERC20 token = IERC20(tokenAddress);
        uint256 contractFee = contractFeeForAuthor(author, tokenAmount);
        token.transferFrom(sender, owner(), contractFee);
        uint256 amount = tokenAmount - contractFee;
        token.transferFrom(sender, ownerOf(author), amount);
        
        uint256 balanseFromEth = converTokenPriceToEth(tokenAddress, tokenAmount);
        addAuthorsRating(balanseFromEth, author);
    }

    // Вспомогательная функция блокировки активов неподтверждённых участников
    function blockTokens(address tokenAddress, uint256 tokenAmount) internal nonReentrant {
        if (tokenAddress != address(0)){
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);
        }
        blockedForWithdraw[tokenAddress] += tokenAmount;
    }

    // Функция донатов в базовом коине
    function donateEth(uint256 author) public payable{        
        require(msg.value >= 10**6, "Low value");
        paymentEth(author, msg.value);
        emit Donate(msg.sender, address(0), msg.value, author);
    }

    // Функция донатов в токенах
    function donateToken(address tokenAddress, uint256 tokenAmount, uint256 author) public{
        require(tokenAmount > 0, "Low value");
        paymentToken(msg.sender, tokenAddress, tokenAmount, author);
        emit Donate(msg.sender, tokenAddress, tokenAmount, author);
    }

    // Функция покупки билета на сессию автора
    function buyTicketForSession(uint256 author, uint256 sessionId) public sessionIsOpenForSender(author, sessionId) payable{
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        address tokenAddress = session.tokenAddress;
        uint256 price = session.price;
        require(tokenAddress == address(0) && price == msg.value || tokenAddress != address(0), "Error value");

        if (whiteListByAuthor[author][msg.sender] || session.typeOf == Types.notModerated){
            if (tokenAddress == address(0)){
                paymentEth(author, msg.value);
            } else {
                paymentToken(msg.sender, tokenAddress, price, author);
            }
            participants.confirmed.push(msg.sender);
            emit PurchaseConfirmed(msg.sender, author, sessionId);
        } else {
            blockTokens(tokenAddress, price);
            participants.notConfirmed.push(msg.sender);
            emit AwaitingConfirmation(msg.sender, author, sessionId);
        }
    }

    // Отмена участия пользователя в сессии в случае, когда его заявке ещё не подтверждена для модерируемых сессий
    function cancelByParticipant(uint256 author, uint256 sessionId) public returns(bool) {
        Session storage session = sessionByAuthor[author][sessionId];
        Participants storage participants = session.participants;
        require(isAddressExist(msg.sender, participants.notConfirmed), "You are not in lists");
        require(!isAddressExist(msg.sender, participants.confirmed), "Contact author to cancel");
        address[] storage notConfirmed = participants.notConfirmed;
        for (uint i = 0; i < notConfirmed.length; i++) {
            if (notConfirmed[i] == msg.sender) {
                notConfirmed[i] = notConfirmed[notConfirmed.length - 1];
                notConfirmed.pop();
                unblockAndReject(msg.sender, session.tokenAddress, session.price);
                emit PurchaseCanceled(msg.sender, author, sessionId);
                return true;
            }
        }
        return false;
    }

    // Голосование пользователей за прошедшую сессию, доступно только участниками один раз
    function voteForSession(bool like, uint256 author, uint256 sessionId) public {
        Session storage session = sessionByAuthor[author][sessionId];
        require(session.expirationTime < block.timestamp, "Session not closed");
        Participants memory participants = session.participants;
        require(isAddressExist(msg.sender, participants.confirmed), "You arent in lists");
        require(!participantVoted[author][sessionId][msg.sender], "Your already voted");
        participantVoted[author][sessionId][msg.sender] = true;
        Rating storage rating = session.rating;
        if (like) {
            rating.like += 1;
        } else {
            rating.dislike += 1;
        }
        emit NewVote(like, msg.sender, author, sessionId);
    }

    // Вспомогательная функция расчёта стоимости токена в базовом коине блокчейна
    function converTokenPriceToEth(address tokenAddress, uint256 tokenAmount) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = uniswapRouter.WETH();
        uint256[] memory amountsOut = uniswapRouter.getAmountsOut(tokenAmount, path);
        return amountsOut[1];
    }
    /***************User interfaces END***************/

    /***************Royalty BGN***************/
    // Функция предназначена для проверки того, поддерживает ли контракт интерфейс расчета комисси для NFT маркетплейсов
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    // Стоимость рояльти владельца контракта для продажи NFT
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId), "nonexistent");
        return (address(this), (salePrice * royaltyFee) / 10000);
    }    

    // Установить рояльти владельца контракта для продажи NFT
    function setRoyaltyFee(uint16 fee) external onlyOwner {
        require (fee < 10000, "too high");
        royaltyFee = fee;
    }

    // Вывести средства в базовом коине, доступные к выводу
    function withdraw() external onlyOwner nonReentrant {
        require(address(this).balance > blockedForWithdraw[address(0)], "not enough");
        uint256 amount = address(this).balance - blockedForWithdraw[address(0)];
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success, "fail");
    }

    // Вывести средства в указанном токене, доступные к выводу
    function withdrawTokens(address _address) external onlyOwner nonReentrant {
        IERC20 token = IERC20(_address);
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance > blockedForWithdraw[_address], "not enough");
        uint256 amount = tokenBalance - blockedForWithdraw[_address];
        token.transfer(_msgSender(), amount);
    }
    /***************Royalty END**************/
}