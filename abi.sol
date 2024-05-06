// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19;

// 開啟 ABI V2 編碼器
pragma experimental ABIEncoderV2;

contract UserDirectory {

    struct Contact {
        string email;
        string phone;
    }
    struct User {
        string name;
        address addr;
        Contact contact;
    }

    address owner;
    mapping (address => User) _users;
    
    // 支援在事件中使用 User struct 參數
    event UserAdded(address indexed addr, User user);
    
    constructor() {
        owner = msg.sender;
    }
    
    // 支援在函示中，使用 User struct 參數。
    function addUser(User memory userInput) public {
    require(msg.sender == owner);
    _users[userInput.addr] = userInput;
    emit UserAdded(userInput.addr, userInput);
}

    
    // 支援在函示中使用 User struct 當回傳值
    function user(address addr) public view returns (User memory) {
    return _users[addr];
}

}