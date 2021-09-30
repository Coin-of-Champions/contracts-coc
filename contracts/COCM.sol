// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
import "./IBEP20.sol";
import "./utils/Context.sol";
import "./COC.sol";

contract COCM is Context, AdminRole {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;

    /**
    * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    address _cocContractAddress;

    struct LockInfo {
        uint256 amountUnlock;
        uint256 swapped;
        uint256 timestampLock;
        bool lockedByAdmin;
        bool unlockManual;
    }
    mapping(address => LockInfo) _addressLockInfo;
    uint256 _TIME_ONE_MONTH = 2629743;
    uint256 _TIME_SIX_MONTH = _TIME_ONE_MONTH * 6;
//    uint256 _TIME_SIX_MONTH = _TIME_ONE_MONTH * 6;
    event BalanceUnlocked(address indexed from, address indexed addressUnlocked);
    event COCMSwapped(address indexed from, uint256 amount);

    constructor(string memory name_, string memory symbol_, uint256 decimals_, address cocContractAddress_){
        _name = name_;
        _symbol = symbol_;
        _decimals = uint8(decimals_);
        _cocContractAddress = cocContractAddress_;
    }

    function changeTokenContract(
        address tokenContract_
    )
    public
    onlyAdmin
    returns (bool)
    {
        _cocContractAddress = tokenContract_;
        return true;
    }

    /**
    * @dev Returns the token name.
    */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Return COC balance locked in contract COCM
     */
    function getCOCLockedInContract() public view returns (uint256) {
        return COC(_cocContractAddress).balanceOf(address(this));
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address) {
        return owner();
    }

    /**
    * @dev Send quantity of `amount_` in balance address `to_`
    * Set rate unlock to 10% and unlock the token after 2629743 blocks than block transaction ( 6 month )
    *
    * Emit `Transfer`
    *
    * Requirements
    * - Caller **MUST** is an admin
    * - User have not already token locked, `balanceOf` == 0
    * - Balance locked in contract **MUST** be > to `amount_`
    */
    function deliverToAccountWithRate10(address to_, uint256 amount_) public onlyAdmin returns (bool) {
        require(_balances[to_] == 0, "COCM: user have already token locked");

        uint256 tokenLocked = getCOCLockedInContract();
        require((tokenLocked - _totalSupply + 1) > amount_, "COCM: Balance enough of token locked");

        _balances[to_] += amount_;
        _totalSupply += amount_;

        LockInfo memory lockInfoAddress;
        lockInfoAddress.amountUnlock = amount_.div(10);
        lockInfoAddress.timestampLock = block.timestamp + _TIME_SIX_MONTH;
        lockInfoAddress.lockedByAdmin = false;
        lockInfoAddress.unlockManual = false;
        lockInfoAddress.swapped = 0;

        _addressLockInfo[to_] = lockInfoAddress;

        emit Transfer(_msgSender(), to_, amount_);
        return true;
    }

    /**
    * @dev Send quantity of `amount_` in balance address `to_`
    * Set rate unlock to 5% and unlock the token after 2629743 blocks than block transaction ( 6 month )
    *
    * Emit `Transfer`
    *
    * Requirements
    * - Caller **MUST** is an admin
    * - User have not already token locked, `balanceOf` == 0
    * - Balance locked in contract **MUST** be > to `amount_`
    */
    function deliverToAccountWithRate5(address to_, uint256 amount_) public onlyAdmin returns (bool) {
        require(_balances[to_] == 0, "COCM: user have already token locked");

        uint256 tokenLocked = getCOCLockedInContract();
        require((tokenLocked - _totalSupply + 1) > amount_, "COCM: Balance enough of token locked");

        _balances[to_] = amount_;
        _totalSupply += amount_;

        LockInfo memory lockInfoAddress;
        lockInfoAddress.amountUnlock = amount_.div(20);
        lockInfoAddress.timestampLock = block.timestamp + _TIME_SIX_MONTH;
        lockInfoAddress.lockedByAdmin = false;
        lockInfoAddress.unlockManual = false;
        lockInfoAddress.swapped = 0;


        _addressLockInfo[to_] = lockInfoAddress;

        emit Transfer(_msgSender(), to_, amount_);
        return true;
    }

    /**
    * @dev Send quantity of `amount_` in balance address `to_`
    * This transfer **MUST** be unlock by admin by `unlockSwap` call
    *
    * Emit `Transfer`
    *
    * Requirements
    * - Caller **MUST** is an admin
    * - User have not already token locked, `balanceOf` == 0
    * - Balance locked in contract **MUST** be > to `amount_`
    */
    function deliverToAccountManual(address to_, uint256 amount_) public onlyAdmin returns (bool) {
        require(_balances[to_] == 0, "COCM: user have already token locked");

        uint256 tokenLocked = getCOCLockedInContract();
        require((tokenLocked - _totalSupply + 1) > amount_, "COCM: Balance enough of token locked");

        _balances[to_] += amount_;
        _totalSupply += amount_;

        LockInfo memory lockInfoAddress;
        lockInfoAddress.amountUnlock = amount_;
        lockInfoAddress.timestampLock = 0;
        lockInfoAddress.lockedByAdmin = true;
        lockInfoAddress.unlockManual = true;
        lockInfoAddress.swapped = 0;


        _addressLockInfo[to_] = lockInfoAddress;

        emit Transfer(_msgSender(), to_, amount_);
        return true;
    }

    /**
    * @dev Returns info of lock token by `owner_` address
    * order of return `amountUnlock`, `timestampUnlock`, `lockedByAdmin`, `unlockManual`
    */
    function getInfoLockedByAddress(address owner_) public view returns(uint256, uint256, bool, bool) {
        uint256 amountUnlock = _addressLockInfo[owner_].amountUnlock;
        uint256 timestampUnlock = _addressLockInfo[owner_].timestampLock;
        bool lockedByAdmin = _addressLockInfo[owner_].lockedByAdmin;
        bool unlockManual = _addressLockInfo[owner_].unlockManual;

        return (amountUnlock, timestampUnlock, lockedByAdmin, unlockManual);
    }

    /**
    * @dev Returns how much token are unlocked by `owner_`
    */
    function getTokenUnlock(address owner_) public view returns(uint256) {
        LockInfo memory lockInfoAddress = _addressLockInfo[owner_];

        if (lockInfoAddress.lockedByAdmin) {
            return 0;
        }
        if (lockInfoAddress.unlockManual) {
            return lockInfoAddress.amountUnlock;
        }

        if (block.timestamp < lockInfoAddress.timestampLock) {
            return 0;
        }
        uint256 rate = (block.timestamp - lockInfoAddress.timestampLock) / _TIME_ONE_MONTH;
        if (rate == 0) {
            return 0;
        }
        if (((lockInfoAddress.amountUnlock * rate) - lockInfoAddress.swapped) > _balances[owner_]) {
            return _balances[owner_];
        }
        return (lockInfoAddress.amountUnlock * rate) - lockInfoAddress.swapped;
    }

    /**
    * @dev Unlock manual swap for `unlockAddress_`
    *
    * Emit `BalanceUnlocked`
    *
    * Requirements:
    * - Swap **MUST** be locked by admin to can unlock it
    */
    function unlockSwap(address unlockAddress_) public onlyAdmin returns(bool) {
        require(_addressLockInfo[unlockAddress_].lockedByAdmin, "COCM: Address amount is not locked by admin");

        _addressLockInfo[unlockAddress_].lockedByAdmin = false;
        emit BalanceUnlocked(_msgSender(), unlockAddress_);
        return true;
    }

    /**
    * @dev Swap COCM unlock in caller address to COC caller address
    *
    * Emit `COCMSwapped`
    *
    * Requirements
    * - Token **MUST** be unlocked
    */
    function swapCOCMtoCOC() public returns(bool) {
        require(_balances[_msgSender()] > 0, "COCM: balance of sender is 0");

        LockInfo memory lockInfoAddress = _addressLockInfo[_msgSender()];
        require(block.timestamp > lockInfoAddress.timestampLock, "COCM: token is already locked");
        require(!lockInfoAddress.lockedByAdmin, "COCM: swap is already locked by admin");
        uint256 tokenToUnlock = getTokenUnlock(_msgSender());

        COC(_cocContractAddress).transfer(_msgSender(), tokenToUnlock);

        _addressLockInfo[_msgSender()].swapped = _addressLockInfo[_msgSender()].swapped + tokenToUnlock;
        _totalSupply = _totalSupply - tokenToUnlock;
        _balances[_msgSender()] = _balances[_msgSender()] - tokenToUnlock;

        emit COCMSwapped(_msgSender(), tokenToUnlock);

        return true;
    }


}
