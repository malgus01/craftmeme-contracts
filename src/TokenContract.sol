// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract TokenContract is ERC20, ERC20Pausable, Ownable {
    error MintingIsDisabled();
    error BurningIsDisabled();
    error MaxSupplyReached();

    uint256 public initialSupply;
    uint256 public maxSupply;
    bool public supplyCapEnabled;
    bool public canMint;
    bool public canBurn;

    constructor(
        address initialOwner,
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _initialSupply,
        uint256 _maxSupply,
        bool _canMint,
        bool _canBurn,
        bool _supplyCapEnabled
    )
        ERC20(tokenName, tokenSymbol)
        Ownable(initialOwner)
    {
        initialSupply = _initialSupply;
        maxSupply = _maxSupply;
        canMint = _canMint;
        canBurn = _canBurn;
        supplyCapEnabled = _supplyCapEnabled;
        _mint(initialOwner, _initialSupply);
    }

    // Mint function (onlyOwner)
    function mint(address to, uint256 amount) external onlyOwner {
        require(canMint, MintingIsDisabled());
        if (supplyCapEnabled) {
            require(totalSupply() + amount <= maxSupply, MaxSupplyReached());
        }
        _mint(to, amount);
    }

    // Burn function
    function burn(uint256 amount) external {
        require(canBurn, BurningIsDisabled());
        _burn(msg.sender, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
