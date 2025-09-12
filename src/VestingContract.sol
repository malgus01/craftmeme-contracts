// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityManager.sol";

/**
 * @title VestingContract
 * @author CraftMeme
 * @dev Implements a token vesting schedule to release tokens over time to beneficiaries.
 * @notice This contract allows the owner to set vesting schedules and beneficiaries to claim vested tokens over time.
 */
contract VestingContract is Ownable {
    ////////////////////
    // Custom Errors //
    //////////////////
    error VestingAlreadySet();
    error NoVestingSchedule();
    error VestingIsRevoked();
    error NoTokensAreDue();
    error AlreadyRevoked();

    //////////////////////
    // State variables //
    ////////////////////
    /// @notice SafeERC20 is used for token transfers
    using SafeERC20 for IERC20;

    /// @notice Liquidity manager contract

    LiquidityManager liquidityManager;

    /// @notice Struct to store vesting schedule data
    struct VestingSchedule {
        address tokenAddress;
        uint256 start;
        uint256 duration;
        uint256 amount;
        uint256 released;
        bool revoked;
    }

    /// @notice Mapping to store vesting schedules
    mapping(address => VestingSchedule) private vestingSchedules;

    /////////////
    // Events //
    ///////////
    /// @notice Emit when tokens are released
    event TokensReleased(address indexed beneficiary, uint256 indexed amount);

    /// @notice Emit when a vesting schedule is revoked
    event VestingRevoked(address indexed beneficiary);

    ////////////////
    // Functions //
    //////////////
    /**
     * @param InitialOwner The initial owner of the contract.
     */
    constructor(address InitialOwner) Ownable(InitialOwner) { }

    /**
     * @notice Sets up a vesting schedule for a beneficiary.
     * @param beneficiary Address of the beneficiary to receive vested tokens.
     * @param tokenAddress Address of the token to be vested.
     * @param start UNIX timestamp for when vesting begins.
     * @param duration Duration of the vesting period in seconds.
     * @param amount Total number of tokens to be vested over the duration.
     * @dev Each beneficiary can only have one active vesting schedule; any attempt to set a new one will revert.
     */
    function setVestingSchedule(
        address beneficiary,
        address tokenAddress,
        uint256 start,
        uint256 duration,
        uint256 amount
    )
        external
        onlyOwner
    {
        require(vestingSchedules[beneficiary].amount == 0, VestingAlreadySet());

        vestingSchedules[beneficiary] = VestingSchedule({
            tokenAddress: tokenAddress,
            start: start,
            duration: duration,
            amount: amount,
            released: 0,
            revoked: false
        });
    }

    /**
     * @notice Releases the vested tokens for a beneficiary based on the elapsed vesting period.
     * @param beneficiary The address of the beneficiary receiving the vested tokens.
     * @dev If the vesting schedule is revoked or no tokens are currently due, this function will revert.
     */
    function release(address beneficiary) public {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.amount > 0, NoVestingSchedule());
        require(!schedule.revoked, VestingIsRevoked());

        uint256 unreleased = vestedAmount(beneficiary) - schedule.released;
        require(unreleased > 0, NoTokensAreDue());

        schedule.released += unreleased;
        IERC20(schedule.tokenAddress).safeTransfer(beneficiary, unreleased);

        emit TokensReleased(beneficiary, unreleased);
    }

    /**
     * @notice Revokes the vesting schedule for a beneficiary.
     * @param beneficiary The address whose vesting schedule is to be revoked.
     * @dev Once revoked, any remaining unvested tokens are no longer claimable by the beneficiary.
     */
    function revoke(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, AlreadyRevoked());

        schedule.revoked = true;
        emit VestingRevoked(beneficiary);
    }

    /**
     * @notice Returns the amount of tokens that have vested for a specific beneficiary.
     * @param beneficiary The address of the beneficiary for whom to calculate vested tokens.
     * @return The amount of tokens vested based on the elapsed vesting period.
     * @dev If the vesting duration has fully elapsed, the full amount is considered vested.
     */
    function vestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (block.timestamp < schedule.start) {
            return 0;
        } else if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.amount;
        } else {
            return (schedule.amount * (block.timestamp - schedule.start)) / schedule.duration;
        }
    }
}
