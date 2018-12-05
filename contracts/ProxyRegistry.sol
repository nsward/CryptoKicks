pragma solidity ^0.4.24;


/**
 * @title OwnableDelegateProxy
 * @dev Interface for the OpenSea OwnableDelegateProxy
 */
contract OwnableDelegateProxy { }


/**
 * @title ProxyRegistry
 * @dev Interface for the OpenSea ProxyRegistry, which allows OpenSea
 * users to buy/sell on the platform without repeated approve() calls
 */
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}