// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Mock Failed Transfer
 * @dev This contract is a mock version of an ERC20 token, primarily designed for testing failure scenarios in token transfer functionalities.
 * It extends ERC20Burnable and Ownable from OpenZeppelin to simulate a scenario where all token transfer attempts fail, returning false to simulate transaction failures.
 *
 * Key Features:
 * - Burn Functionality: Allows the owner to burn tokens, reducing the total supply, with safeguards against burning tokens from an empty or insufficient balance.
 * - Mint Functionality: Provides a public mint function that any caller can use to generate tokens, simulating scenarios where arbitrary minting can occur.
 * - Failed Transfers: Overrides the standard `transfer` function to always return false, simulating a failure in token transfer. This can be used to test systems that interact with tokens and need to handle transfer failures gracefully.
 * - Error Handling: Implements custom error messages for validation failures such as attempting to burn more tokens than available or minting to the zero address.
 *
 * @notice This contract is intended for testing purposes only and should not be used in production systems.
 */


contract MockFailedTransfer is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    /*
    In future versions of OpenZeppelin contracts package, Ownable must be declared with an address of the contract owner
    as a parameter.
    For example:
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {}
    Related code changes can be viewed in this commit:
    https://github.com/OpenZeppelin/openzeppelin-contracts/commit/13d5e0466a9855e9305119ed383e54fc913fdc60
    */
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(address(msg.sender)){}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function transfer(address, /*recipient*/ uint256 /*amount*/ ) public pure override returns (bool) {
        return false;
    }
}