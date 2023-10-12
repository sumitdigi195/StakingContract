// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol"; // for safe arithmetic operations

contract StakingContract {
    using SafeMath for uint256;

    // State variables
    address public owner; // Address of the contract owner
    uint256 public minimumStake; // Minimum staking amount required
    uint256 public lockDuration; // Lock-in period in seconds

    // Struct to represent a validator
    struct Validator {
        uint256 stakedAmount; // Amount staked by the validator
        uint256 esg; // ESG score (scaled decimal with 2 decimal places)
        uint256 lockTimestamp; // Timestamp until which the stake is locked
    }

    // Mapping to store validators and their data
    mapping(address => Validator) public validators;
    // List of registered validators
    address[] public validatorList;

    // Events to log contract actions
    event ValidatorRegistered(address indexed validator, uint256 stakedAmount, uint256 esg);
    event ValidatorUnregistered(address indexed validator);
    event StakeWithdrawn(address indexed validator, uint256 amount);
    event EsgUpdated(address indexed validator, uint256 newEsg);

    // Constructor to initialize the contract with minimum stake and lock duration
    constructor(uint256 _minimumStake, uint256 _lockDuration) {
        owner = msg.sender; // Set the contract owner
        minimumStake = _minimumStake; // Set the minimum staking amount
        lockDuration = _lockDuration; // Set the lock-in period
    }

    // Modifier to restrict access to the contract owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Function to allow validators to register by staking a certain amount
    function registerValidator() external payable {
        require(validators[msg.sender].stakedAmount == 0, "Validator is already registered");
        require(msg.value >= minimumStake, "Staked amount is less than the minimum required");

        // Access the validator's data in storage
        Validator storage validator = validators[msg.sender];
        validator.stakedAmount = msg.value; // Set the staked amount
        validator.esg = 0; // Initialize ESG to 0 (0.00)
        validator.lockTimestamp = block.timestamp + lockDuration; // Set the lock-in period
        validatorList.push(msg.sender); // Add the validator to the list

        // Emit an event to log the registration
        emit ValidatorRegistered(msg.sender, msg.value, 0);
    }

    // Function to allow validators to unregister and withdraw their stake
    function unregisterValidator() external {
        Validator storage validator = validators[msg.sender];
        require(validator.stakedAmount > 0, "Validator is not registered");
        require(block.timestamp >= validator.lockTimestamp, "Staked amount is locked");

        uint256 stakedAmount = validator.stakedAmount;
        uint256 esg = validator.esg;
        validator.stakedAmount = 0; // Reset staked amount
        validator.esg = 0; // Reset ESG score
        validator.lockTimestamp = 0; // Reset the lock-in period

        // Transfer any remaining balance to the validator
        if (address(this).balance >= stakedAmount) {
            payable(msg.sender).transfer(stakedAmount);
        }

        // Emit an event to log the unregistration
        emit ValidatorUnregistered(msg.sender);
        emit EsgUpdated(msg.sender, esg);

        // Remove the validator from the list
        _removeValidatorFromArray(msg.sender);
    }

    // Function to allow validators to withdraw a portion of their stake
    function withdrawStake(uint256 amount) external {
        Validator storage validator = validators[msg.sender];
        require(amount > 0, "Amount must be greater than 0");
        require(validator.stakedAmount >= amount, "Insufficient staked amount");
        require(block.timestamp >= validator.lockTimestamp, "Staked amount is locked");

        validator.stakedAmount = validator.stakedAmount.sub(amount); // Reduce the staked amount

        // Transfer the withdrawn amount back to the validator
        payable(msg.sender).transfer(amount);

        // Emit an event to log the stake withdrawal
        emit StakeWithdrawn(msg.sender, amount);
    }

    // Setter function to update ESG for a validator (scaled by the scaling factor)
    function setEsg(address validatorAddress, uint256 newEsg) external onlyOwner {
        require(validators[validatorAddress].stakedAmount > 0, "Validator is not registered");

        // Update the ESG score for the specified validator
        validators[validatorAddress].esg = newEsg;

        emit EsgUpdated(validatorAddress, newEsg);
    }

    // Function to get the total staked value of all validators
    function getTotalStakedValue() external view returns (uint256) {
        uint256 totalStaked = 0;

        for (uint256 i = 0; i < validatorList.length; i++) {
            address validatorAddress = validatorList[i];
            totalStaked = totalStaked.add(validators[validatorAddress].stakedAmount);
        }

        return totalStaked;
    }

    // Getter function to retrieve the ESG for a validator (scaled by the scaling factor)
    function getEsg(address validatorAddress) external view returns (uint256) {
        return validators[validatorAddress].esg; // Retrieve the ESG score
    }

    // Function to get the list of registered validators
    function getValidatorList() external view returns (address[] memory) {
        return validatorList;
    }

    // Fallback function to allow receiving ether
    receive() external payable {}

    // Internal function to remove a validator from the validatorList
    function _removeValidatorFromArray(address validatorAddress) internal {
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validatorList[i] == validatorAddress) {
                // Move the last element to the position of the removed validator
                validatorList[i] = validatorList[validatorList.length - 1];
                // Remove the last element
                validatorList.pop();
                break;
            }
        }
    }
}

