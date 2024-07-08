// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Emmanuel Acho with special thanks to @PatrickAlphaC (Patrick Collins)
 * @notice Relative Stability: Pegged to the USD
 * @notice DecentralizedStableCoin is a decentralized stablecoin that is pegged to the USD
 * @notice Minting and burning of DecentralizedStableCoin is Algorithmically controlled by DSCEngine
 * @notice Collateral is exogenous to the system (Gold, XAUT, PAXG)
 * 
 * As mentioned above, this contract is the ERC20 implementation of the DecentralizedStableCoin. It is governed by the DSCEngine contract.
 */

contract DecentralizedStableCoin is ERC20Burnable,
 Ownable {
    // errors
    error DecentralizedStableCoin__AmountMustBeGreaterThanZero();
    error DecentralizedStableCoin__BurnAmountIsGreaterThanBalance();
    error DecentralizedStableCoin__YouAreMintingToZeroAddress();

     /*
     * @dev Constructor that sets the initial metadata for the ERC20 token and 
     * initializes the contract ownership.
     * @param initialOwner The initial owner of the contract, who can control owner-only functions.
     */
    // All necessary initializations are handled by base constructors.
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(address(msg.sender)) {}


    // Check the balance of the sender before burning
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
       /* if (amount <= 0 || amount > balance) {
            revert("DecentralizedStableCoin: invalid amount");*/
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeGreaterThanZero(); // revert if the amount is less than or equal to 0
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountIsGreaterThanBalance(); // revert if the amount is greater than the balance
        }
        super.burn(_amount); // Call the burn function from the parent contract
    }

    function mint(address _to, uint256 _amount) external onlyOwner  returns (bool){
        if (_to == address(0)) {
            revert DecentralizedStableCoin__YouAreMintingToZeroAddress(); // revert if the address is 0
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeGreaterThanZero(); // revert if the amount is less than or equal to 0
        }
        _mint(_to, _amount);
        return true;
    }

    
    
 }