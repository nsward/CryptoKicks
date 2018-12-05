pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract StudentRole is Ownable {
    using Roles for Roles.Role;

    event StudentAdded(address indexed account);
    event StudentRemoved(address indexed account);

    Roles.Role private students;

    constructor() internal {
        _addStudent(msg.sender);
    }

    modifier onlyStudent() {
        require(isStudent(msg.sender));
        _;
    }

    function isStudent(address account) public view returns (bool) {
        return students.has(account);
    }

    function addStudent(address account) public onlyOwner {
        _addStudent(account);
    }

    function removeStudent(address account) public onlyOwner {
        _removeStudent(account);
    }

    function renounceStudent() public {
        _removeStudent(msg.sender);
    }

    function _addStudent(address account) internal {
        students.add(account);
        emit StudentAdded(account);
    }

    function _removeStudent(address account) internal {
        students.remove(account);
        emit StudentRemoved(account);
    }
}