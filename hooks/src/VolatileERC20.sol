// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from  "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
/**
 * @title VolatileERC20
 * @notice A ERC20 token that can be minted by its owner and has an expiry date after which the token is no longer valid.
 */
contract VolatileERC20 is ERC20{
    address public owner;
 

    /**
     * @notice Throws if called by any account other than the owner.
     */
    modifier onlyOwner(){
         require(owner == msg.sender,"ONLY OWNER");
        _;
    }

    /** 
     * @notice Initializes the contract setting the token name and symbol, the owner of the contract and the token expiry date.
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     */
    constructor(string memory _name,string memory _symbol) ERC20(_name, _symbol) {
        owner = msg.sender;
    }

    /**
     * @notice Mints a given amount of tokens to a specified address.
     * @param to The address to which the tokens are minted
     * @param value The amount of tokens to mint
     */
    function mint(address to, uint256 value)public  onlyOwner() {
        _mint(to, value);
       
    }

    /**
     * @notice Updates the total supply by minting tokens and handle transfer.
     * @param to The address to which the tokens are minted or transfer
     * @param value The amount of tokens to mint or transfer
     */
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
    }

    
}

