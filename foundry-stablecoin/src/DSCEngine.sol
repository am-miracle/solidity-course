// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title Descentralized stablecoin engine contract (DSCEngine)
/// @notice The system is desgined to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg
/**
 * This stablecoin has the properties:
 *  - Exogenous collateral
 *  - Dollar Pegged
 * - Algorithmic stable
 */
/// It is similar to DAI has no governance, no fees, and was only backed by WETH and WBTC.

/// Our DSC system should always be "overcollateralized". At no point should the value be

/// This contract is the core of the DSC system. It handles all logic for minting and redeeming DSC, as well as despositing & withdrawing collateral
/// @dev This contract is VERY loosely based on the MakerDAO DSS (DAI) system

contract DSCEngine is ReentrancyGuard {
    // Errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreakHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();

    // State Variables
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10%

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposits; // tokenToCollateral
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    // Events
    event DepositCollateral(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    // Modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    // Functions
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price feed
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];

            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    // External Functions

    /**
     * @dev Deposits collateral and mints DSC tokens.
     *
     * This function allows users to deposit a specified amount of collateral tokens and
     * mint a corresponding amount of DSC tokens in one transaction.
     *
     * @param tokenCollateralAddress The address of the token to deposit as collateral.
     * @param amountCollateral The amount of collateral tokens to deposit.
     * @param amountDscToMint The amount of DSC to mint.
     *
     * @example
     * ```
     * // Deposit 100 USDC as collateral and mint 10 DSC tokens
     * depositCollateralAndMintDSC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 100, 10);
     * ```
     */
    function depositCollateralAndMintDSC(
        uint256 tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /**
     * @dev Deposits collateral into the contract.
     * @param tokenCollateralAddress The address of the token being deposited as collateral.
     * @param amountCollateral The amount of collateral being deposited.
     * @notice This function can only be called by an allowed token and the amount must be greater than zero.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposits[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit DepositCollateral(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @dev Redeems collateral for DSC tokens and burns the specified amount of DSC tokens.
     *
     * @param tokenCollateralAddress The address of the collateral token to be redeemed.
     * @param amountCollateral The amount of collateral tokens to be redeemed.
     * @param amountDscToBurn The amount of DSC to be burned.
     *
     * @example
     * ```
     * // Redeem 100 USDC as collateral and burn 50 DSC tokens
     * redeemCollateralForDSC(USDC_ADDRESS, 100, 50);
     * ```
     */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        burnDSC(amountDscToBurn);
    }

    /**
     * In order to redeem collateral:
     *  - The health factor must be over 1 AFTER collateral pulled
     * @param tokenCollateralAddress
     * @param amountCollateral
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        // Get the current collateral balance of the user
        uint256 collateralBalance = s_collateralDeposits[msg.sender][tokenCollateralAddress];
        // Subtract the amount to be redeemed from the user's collateral balance
        collateralBalance -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);
        // Transfer the redeemed collateral to the user
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        _reverIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Mints the specified amount of DSC tokens for the caller. And the must have more collateral value that the minimum threshold
     * @dev This function is non-reentrant and requires the amount to mint to be greater than zero.
     * @param amountDscToMint The amount of DSC tokens to mint.
     * for example:
     * // Mint 100 DSC tokens for the caller.
     * mintDSC(100);
     */
    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if user minted too much, ($150 DSC, $100 ETH)
        _reverIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {
        s_DSCMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amount);
        _reverIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @dev Liquidates a user's collateral to cover their debt.
     * @param collateral The ERC20 collateral address to liquidate from the user.
     * @param user The user who have broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve user health factor.
     * @example
     * ```
     * // Liquidate a user's USDC collateral to cover 10 DSC of debt
     * liquidate(USDC_ADDRESS, userAddress, 10 * 1e18);
     * ```
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // Checks
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        // Effects
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 tokenToRedeemed = tokenAmountFromDebtCovered + bonusCollateral;
        // Interactions
    }

    function getHealthFactor() external view {}

    /// Private and Internal view functions
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @dev Calculates the health factor of a user.
     *
     * The health factor is used to measure measure the ratio of collateral to DSC minted that the user can have.
     * returns how close to liquidation a user is, If a user goes below 1, they can get liquidated
     * @param user The address of the user for whom to calculate the health factor.
     * @return The health factor of the user, represented as a uint256.
     *
     * Example:
     * ```
     * address user = 0x1234567890123456789012345678901234567890;
     * uint256 healthFactor = _healthFactor(user);
     * ```
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _reverIfHealthFactorIsBroken(address user) internal view {
        // 1. check health factor (do they have enough collateral?)
        // 2. revert if the don't
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    /// Public and External View functions
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // 1. get the price of the token in USD
        // 2. convert the usd amount to the token amount
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION)
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount of token deposited, and map it to the price, to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposits[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
