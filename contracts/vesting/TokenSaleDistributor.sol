// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./TokenSaleDistributorStorage.sol";
import "./TokenSaleDistributorProxy.sol";

contract TokenSaleDistributor is ReentrancyGuard, TokenSaleDistributorStorage {
    using SafeERC20 for IERC20;

    event Claimed(address indexed recipient, uint amount);

    /** The token address was set by the administrator. */
    event AdminSetToken(address tokenAddress);

    /// @notice EIP-20 token name for this token
    string public constant name = "v";

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    /********************************************************
     *                                                      *
     *                   PUBLIC FUNCTIONS                   *
     *                                                      *
     ********************************************************/

    /**
     * @notice Claim the tokens that have already vested
     */
    function claim() external nonReentrant {
        uint claimed;

        uint length = allocations[msg.sender].length;
        for (uint i; i < length; ++i) {
            claimed += _claim(allocations[msg.sender][i]);
        }

        if (claimed != 0) {
            emit Claimed(msg.sender, claimed);
        }
    }

    /**
     * @notice Get the total number of allocations for `recipient`
     */
    function totalAllocations(address recipient) external view returns (uint) {
        return allocations[recipient].length;
    }

    /**
     * @notice Get all allocations for `recipient`
     */
    function getUserAllocations(address recipient) external view returns (Allocation[] memory) {
        return allocations[recipient];
    }

    /**
     * @notice Get the total amount of tokens allocated for `recipient`
     */
    function totalAllocated(address recipient) public view returns (uint) {
        uint total;

        uint length = allocations[recipient].length;
        for (uint i; i < length; ++i) {
            total += allocations[recipient][i].amount;
        }

        return total;
    }

    /**
     * @notice Get the total amount of vested tokens for `recipient` so far
     */
    function totalVested(address recipient) external view returns (uint) {
        uint tokensVested;

        uint length = allocations[recipient].length;
        for (uint i; i < length; ++i) {
            tokensVested += _vested(allocations[recipient][i]);
        }

        return tokensVested;
    }

    /**
     * @notice Get the total amount of claimed tokens by `recipient`
     */
    function totalClaimed(address recipient) public view returns (uint) {
        uint total;

        uint length = allocations[recipient].length;
        for (uint i; i < length; ++i) {
            total += allocations[recipient][i].claimed;
        }

        return total;
    }

    /**
     * @notice Get the total amount of claimable tokens by `recipient`
     */
    function totalClaimable(address recipient) external view returns (uint) {
        uint total;

        uint length = allocations[recipient].length;
        for (uint i; i < length; ++i) {
            total += _claimable(allocations[recipient][i]);
        }

        return total;
    }

    /********************************************************
     *                                                      *
     *               ADMIN-ONLY FUNCTIONS                   *
     *                                                      *
     ********************************************************/

    /**
     * @notice Set the amount of purchased tokens per user.
     * @param recipients Token recipients
     * @param isLinear Allocation types
     * @param epochs Vesting epochs
     * @param vestingDurations Vesting period lengths
     * @param cliffs Vesting cliffs, if any
     * @param cliffPercentages Vesting cliff unlock percentages, if any
     * @param amounts Purchased token amounts
     */
    function setAllocations(
        address[] memory recipients,
        bool[] memory isLinear,
        uint[] memory epochs,
        uint[] memory vestingDurations,
        uint[] memory cliffs,
        uint[] memory cliffPercentages,
        uint[] memory amounts
    )
        external
        adminOnly
    {
        require(recipients.length == epochs.length);
        require(recipients.length == isLinear.length);
        require(recipients.length == vestingDurations.length);
        require(recipients.length == cliffs.length);
        require(recipients.length == cliffPercentages.length);
        require(recipients.length == amounts.length);

        uint length = recipients.length;
        for (uint i; i < length; ++i) {
            require(cliffPercentages[i] <= 1e18);

            allocations[recipients[i]].push(
                Allocation(
                    isLinear[i],
                    epochs[i],
                    vestingDurations[i],
                    cliffs[i],
                    cliffPercentages[i],
                    amounts[i],
                    0
                )
            );
        }
    }

    /**
     * @notice Reset all claims data for the given addresses
     * @param targetUser The address data to reset. This will also reduce the voting power of these users.
     */
    function resetAllocationsByUser(address targetUser) external adminOnly {
        // Delete all allocations
        delete allocations[targetUser];
    }

    /**
     * @notice Withdraw deposited tokens from the contract. This method cannot be used with the reward token
     *
     * @param token The token address to withdraw
     * @param amount Amount to withdraw from the contract balance
     */
    function withdraw(address token, uint amount) external adminOnly {
        require(token != tokenAddress, "use resetAllocationsByUser");

        if (amount != 0) {
            IERC20(token).safeTransfer(admin, amount);
        }
    }

    /**
     * @notice Set the vested token address
     * @param newTokenAddress ERC-20 token address
     */
    function setTokenAddress(address newTokenAddress) external adminOnly {
        require(tokenAddress == address(0), "address already set");
        tokenAddress = newTokenAddress;

        emit AdminSetToken(newTokenAddress);
    }

    /**
     * @notice Accept this contract as the implementation for a proxy.
     * @param proxy TokenSaleDistributorProxy
     */
    function becomeImplementation(TokenSaleDistributorProxy proxy) external {
        require(msg.sender == proxy.admin(), "not proxy admin");
        proxy.acceptPendingImplementation();
    }

    /********************************************************
     *                                                      *
     *                  INTERNAL FUNCTIONS                  *
     *                                                      *
     ********************************************************/

    /**
     * @notice Calculate the amount of vested tokens at the time of calling
     * @return Amount of vested tokens
     */
    function _vested(Allocation memory allocation) internal view returns (uint) {
        if (block.timestamp < allocation.epoch + allocation.cliff) {
            return 0;
        }

        uint initialAmount = allocation.amount * allocation.cliffPercentage / 1e18;
        uint postCliffAmount = allocation.amount - initialAmount;
        uint elapsed = block.timestamp - allocation.epoch - allocation.cliff;

        if (allocation.isLinear) {
            if (elapsed >= allocation.vestingDuration) {
                return allocation.amount;
            }

            return initialAmount + (postCliffAmount * elapsed / allocation.vestingDuration);
        }

        uint elapsedPeriods = elapsed / monthlyVestingInterval;
        if (elapsedPeriods >= allocation.vestingDuration) {
            return allocation.amount;
        }

       return initialAmount + (elapsedPeriods * postCliffAmount / allocation.vestingDuration);
    }

    /**
     * @notice Get the amount of claimable tokens for `allocation`
     */
    function _claimable(Allocation memory allocation) internal view returns (uint) {
        return _vested(allocation) - allocation.claimed;
    }

    /**
     * @notice Claim all vested tokens from the allocation
     * @return The amount of claimed tokens
     */
    function _claim(Allocation storage allocation) internal returns (uint) {
        uint claimable = _claimable(allocation);
        if (claimable == 0) {
            return 0;
        }

        allocation.claimed += claimable;
        IERC20(tokenAddress).safeTransfer(msg.sender, claimable);

        return claimable;
    }

    modifier adminOnly {
        require(msg.sender == admin, "admin only");
        _;
    }
}