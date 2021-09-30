// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./COC.sol";
import "hardhat/console.sol";

contract Staking {
    using SafeMath for uint256;

    mapping(address => uint256) private _stakes;

    bool firstWithdraw = true;
    uint256 reflectedFees;
    string public name;
    address public tokenAddress;
    uint256 public stakingStarts;
    uint256 public stakingEnds;
    uint256 public stakedTotal;
    uint256 public stakingCap;
    uint256 public totalReward;
    uint256 public rewardBalance;
    uint256 public stakedBalance;
    uint256 public withdrawStart;

    COC private COCInterface;
    event Staked(
        address indexed token,
        address indexed staker_,
        uint256 requestedAmount_,
        uint256 stakedAmount_
    );
    event PaidOut(
        address indexed token,
        address indexed staker_,
        uint256 amount_,
        uint256 reward_
    );
    event Refunded(
        address indexed token,
        address indexed staker_,
        uint256 amount_
    );

    constructor(
        string memory name_,
        address tokenAddress_,
        uint256 stakingStarts_,
        uint256 stakingEnds_,
        uint256 withdrawStart_,
        uint256 stakingCap_
    ) {
        name = name_;
        require(tokenAddress_ != address(0), "Staking: 0 address");
        tokenAddress = tokenAddress_;

        require(stakingStarts_ > 0, "Staking: zero staking start time");
        if (stakingStarts_ < block.timestamp) {
            stakingStarts = block.timestamp;
        } else {
            stakingStarts = stakingStarts_;
        }

        require(
            stakingEnds_ > stakingStarts,
            "Staking: staking end must be after staking starts"
        );
        stakingEnds = stakingEnds_;

        require(
            withdrawStart_ > stakingEnds_,
            "Staking: withdraw start must be after staking ends"
        );
        withdrawStart = withdrawStart_;

        require(stakingCap_ > 0, "Staking: stakingCap must be positive");
        stakingCap = stakingCap_;
    }

    function addReward(uint256 rewardAmount)
        public
        _before(stakingEnds)
        _hasAllowance(msg.sender, rewardAmount)
        returns (bool)
    {
        require(rewardAmount > 0, "Staking: reward must be positive");

        address from = msg.sender;
        if (!_payMe(from, rewardAmount)) {
            return false;
        }

        totalReward = totalReward.add(rewardAmount);
        rewardBalance = totalReward;
        return true;
    }

    function stakeOf(address account) public view returns (uint256) {
        return _stakes[account];
    }

    /**
     * Requirements:
     * - `amount` Amount to be staked
     */
    function stake(uint256 amount)
        public
        _positive(amount)
        _realAddress(msg.sender)
        returns (bool)
    {
        address from = msg.sender;
        return _stake(from, amount);
    }

    function withdraw(uint256 amount)
        public
        _after(withdrawStart)
        _positive(amount)
        _realAddress(msg.sender)
        returns (bool)
    {
        address from = msg.sender;
        require(amount <= _stakes[from], "Staking: not enough balance");
        if (block.timestamp > stakingEnds) {
            if (firstWithdraw) {
                reflectedFees = COC(tokenAddress)
                    .balanceOf(address(this))
                    .sub(stakedBalance)
                    .sub(totalReward);
                firstWithdraw = false;
                COC(tokenAddress).excludeFromReward(address(this));
            }
            uint256 reward = ((rewardBalance.mul(amount)).div(stakedBalance));
            uint256 rewardFee = (reflectedFees.mul(amount)).div(stakedBalance);

            uint256 payOut = amount.add(reward).add(rewardFee);
            _stakes[from] = _stakes[from].sub(amount);
            if (_payDirect(from, payOut)) {
                emit PaidOut(tokenAddress, from, amount, reward);
                return true;
            }
            return false;
        } else return false;
    }

    function _stake(address staker, uint256 amount)
        private
        _after(stakingStarts)
        _before(stakingEnds)
        _positive(amount)
        _hasAllowance(staker, amount)
        returns (bool)
    {
        // check the remaining amount to be staked
        uint256 remaining = amount;
        if (remaining > (stakingCap.sub(stakedBalance))) {
            remaining = stakingCap.sub(stakedBalance);
        }
        // These requires are not necessary, because it will never happen, but won't hurt to double check
        // this is because stakedTotal and stakedBalance are only modified in this method during the staking period
        require(remaining > 0, "Staking: Staking cap is filled");
        require(
            (remaining + stakedTotal) <= stakingCap,
            "Staking: this will increase staking amount pass the cap"
        );
        if (!_payMe(staker, remaining)) {
            return false;
        }
        emit Staked(tokenAddress, staker, amount, remaining);

        if (remaining < amount) {
            // Return the unstaked amount to sender (from allowance)
            uint256 refund = amount.sub(remaining);
            if (_payTo(staker, staker, refund)) {
                emit Refunded(tokenAddress, staker, refund);
            }
        }

        // Transfer is completed
        stakedBalance = stakedBalance.add(remaining);
        stakedTotal = stakedTotal.add(remaining);
        _stakes[staker] = _stakes[staker].add(remaining);
        return true;
    }

    function _payMe(address payer, uint256 amount) private returns (bool) {
        return _payTo(payer, address(this), amount);
    }

    function _payTo(
        address allower,
        address receiver,
        uint256 amount
    ) private _hasAllowance(allower, amount) returns (bool) {
        // Request to transfer amount from the contract to receiver.
        // contract does not own the funds, so the allower must have added allowance to the contract
        // Allower is the original owner.
        COCInterface = COC(tokenAddress);
        return COCInterface.transferFrom(allower, receiver, amount);
    }

    function _payDirect(address to, uint256 amount)
        private
        _positive(amount)
        returns (bool)
    {
        COCInterface = COC(tokenAddress);
        return COCInterface.transfer(to, amount);
    }

    modifier _realAddress(address addr) {
        require(addr != address(0), "Staking: zero address");
        _;
    }

    modifier _positive(uint256 amount) {
        require(amount >= 0, "Staking: negative amount");
        _;
    }

    modifier _after(uint256 eventTime) {
        require(
            block.timestamp >= eventTime,
            "Staking: bad timing for the request"
        );
        _;
    }

    modifier _before(uint256 eventTime) {
        require(
            block.timestamp < eventTime,
            "Staking: bad timing for the request"
        );
        _;
    }

    modifier _hasAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        COCInterface = COC(tokenAddress);
        uint256 ourAllowance = COCInterface.allowance(allower, address(this));
        require(
            amount <= ourAllowance,
            "Staking: Make sure to add enough allowance"
        );
        _;
    }
}
