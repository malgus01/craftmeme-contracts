// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityManager.sol";

/**
 * @title VestingContract
 * @author CraftMeme
 * @dev A token vesting contract that will release tokens over time to beneficiaries.
 */
contract VestingContract is Ownable {
    error VestingAlreadySet();
    error NoVestingSchedule();
    error VestingIsRevoked();
    error NoTokensAreDue();
    error AlreadyRevoked();

    using SafeERC20 for IERC20;

    LiquidityManager liquidityManager;

    struct VestingSchedule {
        address tokenAddress;
        uint256 start;
        uint256 duration;
        uint256 amount;
        uint256 released;
        bool revoked;
    }

    mapping(address => VestingSchedule) private vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 indexed amount);
    event VestingRevoked(address indexed beneficiary);

    constructor(address InitialOwner) Ownable(InitialOwner) { }

    /**
     * @dev Sets up a vesting schedule for a beneficiary.
     * @param beneficiary Address of the beneficiary.
     * @param start Vesting start time (in UNIX timestamp).
     * @param duration Duration of the vesting period in seconds.
     * @param amount Total number of tokens to be vested.
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
     * @dev Releases vested tokens to the beneficiary.
     * @param beneficiary The address receiving the vested tokens.
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
     * @dev Revokes the vesting schedule for a beneficiary.
     * @param beneficiary The address whose vesting schedule is being revoked.
     */
    function revoke(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(!schedule.revoked, AlreadyRevoked());

        schedule.revoked = true;
        emit VestingRevoked(beneficiary);
    }

    /**
     * @dev Returns the amount of tokens that have vested for a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @return The amount of tokens vested.
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
