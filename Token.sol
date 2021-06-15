// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/Address.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/utils/SafeERC20.sol";


contract rLDAOToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("LiquiDAO Redeem Token", "rLDAO") {
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}


contract PurchaseWithUSDt is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using Address for address payable;
    
    address payable public wallet;
    ERC20 public token;
    ERC20 public fundingToken;

    event TokenPurchase(
        address indexed beneficiary,
        uint256 value,
        uint256 tokens
    );

    constructor(
        ERC20 _token,
        ERC20 _fundingToken,
        address payable _wallet
    ) {
        wallet = _wallet;
        token = _token;
        fundingToken = _fundingToken;
    }

    function buyTokens() public {
        require(validPurchase());

        uint256 allowedAmount =
            fundingToken.allowance(msg.sender, address(this));
        address beneficiary = msg.sender;

        // the rate is 1 rLDAO for 1 USDt
        uint256 tokens = allowedAmount;

        ERC20(fundingToken).safeTransferFrom(msg.sender, wallet, tokens);

        // transfer rLDAO tokens to investors
        ERC20(token).transfer(beneficiary, tokens);

        emit TokenPurchase(beneficiary, allowedAmount, tokens);
    }

    function flush() public onlyOwner {
        uint256 unsold = token.balanceOf(address(this));
        uint256 stuckFunding = fundingToken.balanceOf(address(this));

        if (unsold > 0) {
            token.transfer(msg.sender, unsold);
        }

        if (stuckFunding > 0) {
            fundingToken.transfer(msg.sender, stuckFunding);
        }
    }

    // @return true if the purchaser is allowed to buy tokens
    function validPurchase() internal view returns (bool) {
        uint256 fundingAmount =
            fundingToken.allowance(msg.sender, address(this));
        bool nonZeroPurchase = fundingAmount > 0;
        bool withinBalance = fundingAmount < token.balanceOf(address(this));

        return withinBalance && nonZeroPurchase;
    }
}

contract PurchaseWithETH is Ownable {
    address payable public wallet;
    rLDAOToken public token;

    event TokenPurchase(
        address indexed beneficiary,
        uint256 value,
        uint256 tokens
    );

    constructor(rLDAOToken _token, address payable _wallet) {
        wallet = _wallet;
        token = _token;
    }

    receive() external payable {
        // React to receiving ether
        buyTokens();
    }

    function buyTokens() public payable {
        require(validPurchase());

        uint256 weiAmount = msg.value;
        address beneficiary = msg.sender;

        //send ETH to wallet
        wallet.transfer(weiAmount);

        // the rate is 1 rLDAO for 1 ETH
        uint256 tokens = weiAmount;

        // transfer tokens to investor
        token.transfer(beneficiary, tokens);

        emit TokenPurchase(beneficiary, weiAmount, tokens);
    }

    function withdraw() public onlyOwner {
        uint256 unsold = token.balanceOf(address(this));

        if (unsold > 0) {
            token.transfer(msg.sender, unsold);
        }
    }

    // @return true if the purchaser is allowed to buy tokens
    function validPurchase() internal returns (bool) {
        bool nonZeroPurchase = msg.value != 0;
        bool withinBalance = msg.value < token.balanceOf(address(this));

        return withinBalance && nonZeroPurchase;
    }
}
