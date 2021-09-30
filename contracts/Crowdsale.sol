// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './IBEP20.sol';
import './utils/Ownable.sol';
import "./utils/AdminRole.sol";
import "./utils/SafeMath.sol";

contract Crowdsale is AdminRole {
    using SafeMath for uint256;

    address private _tokenContract;

    uint private _salesIndex;
    mapping(uint => Sale) private _sales;

    event NewSale(uint salesIndex, uint startDate, uint endDate, uint quantity, uint price);
    event Buy(address buyer, uint quantity, uint price);

    struct Sale {
        uint startDate;
        uint endDate;
        uint quantity;
        uint price;
    }

    // referral struct
    struct ReferralInfo {
        address referralAddress;
        uint256 rate;
        bool active;
    }
    mapping(string => ReferralInfo) private _referralsCodeInfo;
    mapping(address => string[]) _referralsAddress;

    mapping(address => uint256) _referralsEarns;
    uint256 _totalEarns;

    mapping(address => bool) private _whitelistAddress;

    // FUNCTION
    constructor(address tokenContract_) {
        _tokenContract = tokenContract_;
        _salesIndex = 0;
    }

    function changeTokenContract(address tokenContract_) public onlyAdmin returns (bool) {
        require(_sales[_salesIndex].endDate < block.timestamp);
        _tokenContract = tokenContract_;
        return true;
    }

    function getTokenContract() public view returns (address) {
        return _tokenContract;
    }

    function createSale(uint startDate_, uint endDate_, uint quantity_, uint price_) public onlyAdmin returns (bool) {
        require(endDate_ > startDate_, "CRW: end date is in the past");
        require(block.timestamp > _sales[_salesIndex].endDate, "CRW: previous sale is not closed yet");

        require(IBEP20(_tokenContract).balanceOf(_msgSender()) >= quantity_, "CRW: balance of sender is not enough");
        require(IBEP20(_tokenContract).allowance(_msgSender(), address(this)) >= quantity_, "CRW: allowance of contract is not enough");
        require(IBEP20(_tokenContract).transferFrom(_msgSender(), address(this), quantity_), "CRW: error during transfer from");

        _salesIndex == _salesIndex++;

        Sale memory c;
        c.startDate = startDate_;
        c.endDate = endDate_;
        c.quantity = quantity_;
        c.price = price_;

        _sales[_salesIndex] = c;

        emit NewSale(_salesIndex, c.startDate, c.endDate, c.quantity, c.price);

        return true;
    }

    function buy(uint amount_, string memory referralCode_) public payable returns (bool) {

        Sale storage c = _sales[_salesIndex];

        uint256 priceToPay = (amount_ * c.price) / 10 ** 18;
        require(msg.value ==  priceToPay, "CRW: Price doesn't match quantity");
        require(block.timestamp > c.startDate, "CRW: Sale didn't start yet.");
        require(block.timestamp < c.endDate, "CRW: Sale is already closed.");
        require(amount_ <= c.quantity, "CRW: Amount over the limit");

        IBEP20(_tokenContract).transfer(msg.sender, amount_);
        c.quantity = c.quantity - amount_;

        // deliver bnb to referral address is exist and is active
        if(_referralsCodeInfo[referralCode_].referralAddress != address(0) && _referralsCodeInfo[referralCode_].active) {
            address referralAddress = _referralsCodeInfo[referralCode_].referralAddress;
            // calc rate bnb to send
            uint256 rateToDeliver = priceToPay.div(100).mul(_referralsCodeInfo[referralCode_].rate);
            _referralsEarns[referralAddress] += rateToDeliver;
            _totalEarns += rateToDeliver;
        }

        emit Buy(msg.sender, amount_, c.price);
        return true;
    }

    function forceClose() public onlyAdmin returns (bool) {
        Sale storage c = _sales[_salesIndex];

        require(c.endDate > block.timestamp, "CRW: sale is not finished");
        c.endDate = block.timestamp;

        if ( c.quantity > 0 ) {
            require(IBEP20(_tokenContract).transfer(_msgSender(), _sales[_salesIndex].quantity));
            c.quantity = 0;
        }

        return true;
    }

    function getBalance() public view returns(uint) {
        uint256 totalBalance = address(this).balance.sub(_totalEarns);
        return totalBalance;
    }

    function withdrawToken(uint salesIndex_) public onlyAdmin returns (bool) {
        Sale storage c = _sales[salesIndex_];

        require(c.endDate < block.timestamp, "CRW: sale is not closed yet");
        require(c.quantity > 0, "CRW: no tokens to withdraw");

        IBEP20(_tokenContract).transfer(_msgSender(), c.quantity);
        c.quantity = 0;

        return true;
    }

    function withdrawBNB() public onlyAdmin returns (bool) {
        require(getBalance() > 0, "CRW: no bnb to withdraw");
        address payable to = payable(msg.sender);
        to.transfer(getBalance());
        return true;
    }

    function getInfoSale(uint salesIndex_) public view returns(Sale memory) {
        return _sales[salesIndex_];
    }

    function getLastSaleIndex() public view returns(uint) {
        return _salesIndex;
    }

    function addReferralCode(address referralAddress_, string memory referralCode_, uint256 rate_) public onlyAdmin returns (bool) {
        require(_referralsCodeInfo[referralCode_].referralAddress == address(0), "CRW: referralAddress have already a referralCode");
        require(rate_ > 0, "CRW: rate must be greater than 0");

        bytes memory strBytes = bytes(referralCode_);
        require(strBytes.length > 0, "CRW: referral code cannot be empty");

        ReferralInfo memory referralInfo;
        referralInfo.referralAddress = referralAddress_;
        referralInfo.rate = rate_;
        referralInfo.active = true;

        _referralsCodeInfo[referralCode_] = referralInfo;
        _referralsAddress[referralAddress_].push(referralCode_);

        return true;
    }

    function disableReferralCode(string memory referralCode_) public onlyAdmin returns (bool) {
        require(_referralsCodeInfo[referralCode_].referralAddress != address(0), "CRW: referral code not exist");
        require(_referralsCodeInfo[referralCode_].active, "CRW: referral code is already disabled");

        _referralsCodeInfo[referralCode_].active = false;

        return true;
    }

    function getReferralCodeByAddress(address referralAddress_) public view returns(string[] memory) {
        return _referralsAddress[referralAddress_];
    }

    function getReferralCodeInfo(string memory referralCode_) public view returns(ReferralInfo memory) {
        return _referralsCodeInfo[referralCode_];
    }

    function getBnbEarnedByAddress(address referralAddress_) public view returns(uint256){
        return _referralsEarns[referralAddress_];
    }

    function withdrawReferralBNB() public returns (bool) {
        require(_referralsEarns[_msgSender()] > 0, "CRW: no bnb earn by caller");
        address payable to = payable(msg.sender);
        to.transfer(_referralsEarns[_msgSender()]);

        _totalEarns = _totalEarns - _referralsEarns[_msgSender()];
        _referralsEarns[_msgSender()] = 0;
        return true;
    }
}
