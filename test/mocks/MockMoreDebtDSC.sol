// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;





import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

/**
 * @title Mock More Debt Decentralized StableCoin (MockMoreDebtDSC)
 * @dev This contract extends the ERC20Burnable and Ownable contracts from OpenZeppelin to create a testable stablecoin that is pegged to USD.
 * The contract is designed primarily for testing environments, not for production use. It includes mechanisms to simulate extreme market conditions,
 * specifically allowing for the manipulation of the collateral's market price through a Mock V3 Aggregator.
 *
 * Features:
 * - Burn and Mint: The contract allows the owner to mint new tokens or burn existing tokens, providing basic functionalities of a stablecoin.
 * - Price Manipulation: Includes an integration with a mock price feed (MockV3Aggregator) to simulate dramatic changes in the underlying collateral's price,
 *   such as crashing the price to zero during a burn operation. This feature is crucial for testing the stablecoin's resilience and response mechanisms
 *   under adverse conditions.
 * - Error Handling: Implements custom errors for various fail states like zero address checks and balance validations to ensure robust error management.
 * - Ownership Controls: Utilizes the Ownable pattern to restrict critical functionalities like minting and burning to the contract owner, enhancing security.
 *
 * @notice Use this contract only for development and testing purposes as it includes features that allow deliberate destabilization of the token's market conditions.
 */
contract MockMoreDebtDSC is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    address mockAggregator;

    /*
    In future versions of OpenZeppelin contracts package, Ownable must be declared with an address of the contract owner
    as a parameter.
    For example:
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {}
    Related code changes can be viewed in this commit:
    https://github.com/OpenZeppelin/openzeppelin-contracts/commit/13d5e0466a9855e9305119ed383e54fc913fdc60
    */
    constructor(address _mockAggregator) ERC20("DecentralizedStableCoin", "DSC") Ownable(address(msg.sender)) {
        mockAggregator = _mockAggregator;
    }

    function burn(uint256 _amount) public override onlyOwner {
        // We crash the price
        MockV3Aggregator(mockAggregator).updateAnswer(0);
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}