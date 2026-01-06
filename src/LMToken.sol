// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LMToken
 * @notice The native token of the LendMachine protocol
 * @dev Used as the borrowable asset in the lending pool
 */
contract LMToken is ERC20, Ownable {
    /// @notice Maximum supply cap (100 million tokens)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18;

    /// @notice Addresses authorized to mint tokens
    mapping(address => bool) public minters;

    /// @notice Emitted when a minter is added or removed
    event MinterUpdated(address indexed minter, bool status);

    /**
     * @notice Constructor
     * @param initialOwner The initial owner of the contract
     */
    constructor(address initialOwner) ERC20("LendMachine Token", "LMT") Ownable(initialOwner) {
        // Mint initial supply to owner for liquidity provisioning
        _mint(initialOwner, 10_000_000 * 1e18);
    }

    /**
     * @notice Mints new tokens
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender] || msg.sender == owner(), "LMToken: not authorized");
        require(totalSupply() + amount <= MAX_SUPPLY, "LMToken: max supply exceeded");
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from the caller
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from a specific address (requires approval)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /**
     * @notice Sets or revokes minter status for an address
     * @param minter The address to update
     * @param status Whether the address can mint
     */
    function setMinter(address minter, bool status) external onlyOwner {
        minters[minter] = status;
        emit MinterUpdated(minter, status);
    }
}
