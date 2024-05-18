// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./RealT.sol";

contract CryptoAbode {
    address private _admin;
    RealT private realT;

    struct UserDetails {
        uint id;
        uint user_type; // 1: 管理員, 2: 審計員, 3: 買家 / 賣家
        string name;
        string contact;
        string location;
        uint[] estates;
    }

    struct EstateListing {
        string estateAddress;
        uint requiredPrice;
        string imgUrl;
        string features;
        bool toBeSold;
        address owner;
        bool isVerified;
        uint estateType; // 1: 買/賣, 2: 租賃
        uint months;
        address highestBidder;
        uint highestBid;
    }

    mapping(address => UserDetails) public users;
    mapping(uint => EstateListing) public listedEstates;
    uint public numEstates = 0;
    uint public numUsers = 0;
    address[] public userAddrs;

    event InitUser(address indexed _user, RealT realT);
    event AddUser(address indexed _user, uint _userId);
    event AddEstate(address indexed _owner, uint _estateID);
    event TransferEstate(address indexed _seller, address indexed _buyer, uint _estateID);

    // 管理員修飾符
    modifier onlyAdmin() {
        require(msg.sender == _admin, "Caller is not admin");
        _;
    }

    // 審計員修飾符
    modifier onlyAuditor() {
        require(users[msg.sender].user_type == 2, "Caller is not auditor");
        _;
    }

    // 買家或賣家修飾符
    modifier onlyBuyerOrSeller() {
        require(users[msg.sender].user_type == 3, "Caller is not buyer or seller");
        _;
    }

    // 已驗證房產修飾符
    modifier onlyVerifiedProperty(uint estateIndex) {
        require(listedEstates[estateIndex].isVerified, "Property is not verified");
        _;
    }

    // 建構函數
    constructor(address tokenAddress) {
        realT = RealT(tokenAddress);
        _admin = msg.sender;
        users[msg.sender].user_type = 1;
        emit InitUser(msg.sender, realT);
    }

    // 獲取批准市場的地址
    function fetchApprovedMarket() public view returns(address) {
        return realT.fetchApprovedMarket();
    }

    // 添加合約餘額
    function addContractBalance() public payable {}

    // 添加用戶
    function addUser(string memory name, string memory contact, string memory location) public {
        numUsers++;
        UserDetails memory user = UserDetails({
            id: numUsers,
            name: name,
            contact: contact,
            location: location,
            user_type: 0,
            estates: new uint[](0)
        });
        users[msg.sender] = user;
        userAddrs.push(msg.sender);
        emit AddUser(msg.sender, numUsers);
    }

    // 註冊用戶（僅限管理員）
    function registerUser(address userAddr, uint user_type) public onlyAdmin {
        require(user_type == 2 || user_type == 3, "Invalid user type");
        users[userAddr].user_type = user_type;
        transferRealTToken(userAddr, 100 * 10**18);
    }

    // 驗證房產（僅限審計員）
    function verifyProperty(uint estateIndex) public onlyAuditor {
        listedEstates[estateIndex].isVerified = true;
    }

    // 獲取合約餘額
    function getContractBalance() public view returns(uint) {
        return address(this).balance;
    }

    // 添加房產
    function addEstate(
        string memory _location,
        uint _cost,
        string memory imageURL,
        string memory feat
    ) public returns(bool) {
        numEstates++;
        EstateListing memory myEstate = EstateListing({
            owner: msg.sender,
            estateAddress: _location,
            requiredPrice: _cost,
            imgUrl: imageURL,
            features: feat,
            toBeSold: true,
            isVerified: false,
            months: 0,
            estateType: 1,
            highestBid: _cost,
            highestBidder: address(0)
        });
        listedEstates[numEstates] = myEstate;
        users[msg.sender].estates.push(numEstates);
        emit AddEstate(msg.sender, numEstates);
        return true;
    }

    // 獲取房產詳情
    function getEstateDetails(uint _index) public view returns (
        string memory, uint, string memory, string memory, bool, address, bool
    ) {
        EstateListing memory estate = listedEstates[_index];
        return (
            estate.estateAddress,
            estate.requiredPrice,
            estate.imgUrl,
            estate.features,
            estate.toBeSold,
            estate.owner,
            estate.isVerified
        );
    }

    // 獲取房產總數
    function getEstateCount() public view returns (uint) {
        return numEstates;
    }

    // 獲取用戶地址列表
    function getUserAddresses() public view returns (address[] memory) {
        return userAddrs;
    }

    // 檢查是否為管理員
    function checkIfAdmin() external view returns(bool) {
        return _admin == msg.sender;
    }

    // 檢查是否為審計員
    function checkIfAuditor() external view returns(bool) {
        return users[msg.sender].user_type == 2;
    }

    // 獲取用戶資訊（僅限管理員）
    function getUser(address userAddr) public onlyAdmin view returns (
        uint, uint, string memory, string memory, string memory, uint[] memory
    ) {
        UserDetails memory user = users[userAddr];
        return (
            user.id,
            user.user_type,
            user.name,
            user.contact,
            user.location,
            user.estates
        );
    }

    // 出價購買房產
    function placeBid(uint estateIndex, uint bidValue) public onlyVerifiedProperty(estateIndex) onlyBuyerOrSeller payable {
        require(bidValue >= listedEstates[estateIndex].highestBid, "Bid is too low");
        require(msg.sender != listedEstates[estateIndex].owner, "Owner cannot bid");
        require(listedEstates[estateIndex].toBeSold, "Estate not for sale");
        require(listedEstates[estateIndex].estateType == 1, "Estate not sellable");
        checkRealTAndBid(bidValue);

        address previousHighestBidder = listedEstates[estateIndex].highestBidder;
        uint previousHighestBid = listedEstates[estateIndex].highestBid;

        listedEstates[estateIndex].highestBid = bidValue;
        listedEstates[estateIndex].highestBidder = msg.sender;

        if (previousHighestBidder != address(0)) {
            realT.approve(listedEstates[estateIndex].owner, previousHighestBid);
            realT.transferFrom(listedEstates[estateIndex].owner, previousHighestBidder, previousHighestBid);
        }

        transferRealTToken(listedEstates[estateIndex].owner, bidValue);
    }

    // 停止房產競標
    function stopBidding(uint estateIndex) public onlyVerifiedProperty(estateIndex) onlyBuyerOrSeller payable {
        require(listedEstates[estateIndex].owner == msg.sender, "Only owner can stop the bid");
        require(listedEstates[estateIndex].toBeSold, "Estate not for sale");
        require(listedEstates[estateIndex].estateType == 1, "Estate not sellable");

        listedEstates[estateIndex].toBeSold = false;
        listedEstates[estateIndex].owner = listedEstates[estateIndex].highestBidder;
        listedEstates[estateIndex].highestBidder = address(0);
    }

    // 獲取RealT餘額
    function getRealTBalance() public view returns(uint) {
        return realT.balanceOf(msg.sender);
    }

    // 檢查RealT餘額和出價
    function checkRealTAndBid(uint bid) internal view {
        require(bid <= realT.balanceOf(msg.sender), "Not enough RealT tokens");
    }

    // 轉移RealT代幣
    function transferRealTToken(address to, uint amount) public {
        realT.approve(msg.sender, amount);
        realT.transferFrom(msg.sender, to, amount);
    }

    // 空投RealT代幣（僅限管理員）
    function transferRealTTokenAirDrop(address to, uint amount) public onlyAdmin {
        realT.approve(msg.sender, amount);
        realT.transferFrom(msg.sender, to, amount);
    }
}
