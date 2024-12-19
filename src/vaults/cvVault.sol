// // SPDX-License-Identifier: TBD
// pragma solidity 0.8.19;

// import {
//     ERC4626,
//     ERC20,
//     IERC20
// } from "@openzeppelin-contracts-4.9.6/token/ERC20/extensions/ERC4626.sol";
// import {SafeERC20} from "@openzeppelin-contracts-4.9.6/token/ERC20/utils/SafeERC20.sol";
// import {Ownable} from "@openzeppelin-contracts-4.9.6/access/Ownable.sol";

// interface IcvToken {
//     function underlying() external view returns (address);
//     function convertsTo() external view returns (address);
// }

// interface IcvStrategy {
//     function totalAssets() external view returns (uint256);
//     function currentRewards() external view returns (uint256);
//     function currentHedgedBalance() external view returns (uint256);
//     function withdrawCvToken(uint256) external;
//     function withdrawRewardToken(uint256) external;
// }

// /// @notice The cvVault is purpose built for executing strategies with tokens that cannot be compounded.
// ///         The underlying/deposit token is not compoundable, but can earn yield in another token.
// ///         Therefore, we combine the functionality of a staking contract with a ERC4626 vault so the position is tokenized.
// ///         We use ERC4626 instead of a regular ERC20 as the receipt token to allow the vault to perform operations that change the underlying balance,
// ///         such as market making.
// contract cvVault is Ownable, ERC4626 {
//     using SafeERC20 for IERC20;

//     // ========== ERRORS ========== //

//     error InvalidParam(string name);
//     error NonTransferable();

//     // ========== EVENTS ========== //

//     // ========== STATE VARIABLES ========== //

//     IcvStrategy public strategy;
//     bool public initialized;

//     // Tokens
//     IERC20 public immutable hedgedToken;
//     IERC20 public immutable rewardToken;

//     // Vault Yield
//     uint256 public paidRewards;
//     uint256 public yieldIndex;
//     mapping(address holder => uint256) public userIndex; // adjusted by user deposits, claims, and withdrawals

//     // ========== CONSTRUCTOR ========== //

//     constructor(
//         string memory name_,
//         string memory symbol_,
//         address cvToken_
//     ) ERC4626(IERC20(cvToken_)) ERC20(name_, symbol_) Ownable() {
//         // The reward token is the token that the cvToken is denominated in, aka, it's underlying token
//         rewardToken = IERC20(IcvToken(cvToken_).underlying());

//         // The hedged token is the token that the cvToken converts to
//         hedgedToken = IERC20(IcvToken(cvToken_).convertsTo());
//     }

//     // ========== MODIFIERS ========== //

//     modifier updateYieldIndex() {
//         _updateYieldIndex();
//         _;
//     }

//     function _updateYieldIndex() internal {
//         yieldIndex = currentYieldIndex();
//     }

//     // ========== INITIALIZE ========== //

//     function initialize(
//         address strategy_
//     ) public onlyOwner {
//         if (strategy_ == address(0)) revert InvalidParam("strategy");
//         strategy = IcvStrategy(strategy_);
//         initialized = true;
//     }

//     // ========== DEPOSIT/WITHDRAWAL FUNCTIONS ========== //

//     // TODO the in/out functions of the vault need to be thought through a bit more
//     // I don't know if using the ERC4626 standard is the best way to handle this now

//     function deposit(
//         uint256 assets,
//         address receiver
//     ) public override updateYieldIndex returns (uint256 shares) {
//         // Require that the receiver is the sender
//         // This is done so that other's cannot modify a user's yield index
//         if (receiver != msg.sender) revert InvalidParam("receiver");

//         // Cache the user's current yield index and balance
//         uint256 prevUserIndex = userIndex[receiver];
//         uint256 prevUserBalance = balanceOf(receiver);

//         // Deposit the assets and get the amount of shares minted
//         shares = super.deposit(assets, receiver);

//         // TODO send assets to strategy

//         // Set the user's updated yield index
//         // By taking a weighted average of the previous yield index and the current yield index
//         // We round this calculation up to ensure that user's cannot gain extra yield by depositing
//         uint256 numer = prevUserIndex * prevUserBalance + yieldIndex * shares;
//         uint256 denom = prevUserBalance + shares;
//         userIndex[receiver] = numer / denom + (numer % denom == 0 ? 0 : 1);
//     }

//     function mint(
//         uint256 shares,
//         address receiver
//     ) public override updateYieldIndex returns (uint256 assets) {
//         // Require that the receiver is the sender
//         // This is done so that other's cannot modify a user's yield index
//         if (receiver != msg.sender) revert InvalidParam("receiver");

//         // Cache the user's current yield index and balance
//         uint256 prevUserIndex = userIndex[receiver];
//         uint256 prevUserBalance = balanceOf(receiver);

//         // Mint the shares and get the amount of assets deposited
//         assets = super.mint(shares, receiver);

//         // TODO send assets to strategy

//         // Set the user's updated yield index
//         // By taking a weighted average of the previous yield index and the current yield index
//         // We round this calculation up to ensure that user's cannot gain extra yield by depositing
//         uint256 numer = prevUserIndex * prevUserBalance + yieldIndex * shares;
//         uint256 denom = prevUserBalance + shares;
//         userIndex[receiver] = numer / denom + (numer % denom == 0 ? 0 : 1);
//     }

//     // TODO there are various states the user's position can be in when attempting to withdraw
//     // 1. The user's index is less than the global index -> user has net rewards that can be claimed with the withdrawal
//     // 2. The user's index is equal to the global index -> user has no net rewards to claim
//     // 3. The user's index is greater than the global index -> user has negative rewards, they must pay to withdraw
//     // The first two are fairly easy to handle
//     // The third could be handled in multiple ways, including:
//     // a. converting cvTokens to cover the deficient (they receive fewer back) -> worst option if price < cvPrice, potentially best is price > cvPrice
//     // b. having the user provide hedged tokens
//     // c. having the user provide reward tokens
//     // The last is probably the easiest to implement since it doesn't require paying back the short
//     // However, it would require an action by the manager to update the hedge
//     // The second option (b) maintains the hedge, but requires users to buy the hedged token and provide to the vault
//     // The manager would then need to initiate the payback (maybe, could do it in the withdraw/redeem transaction, but adds gas)

//     function withdraw(
//         uint256 assets,
//         address receiver,
//         address owner
//     ) public override updateYieldIndex returns (uint256 shares) {
//         // Require that the owner is the sender
//         if (owner != msg.sender) revert InvalidParam("owner");

//         // TODO pull assets from strategy

//         return super.withdraw(assets, receiver, owner);
//     }

//     function redeem(
//         uint256 shares,
//         address receiver,
//         address owner
//     ) public override updateYieldIndex returns (uint256 assets) {
//         // Require that the owner is the sender
//         if (owner != msg.sender) revert InvalidParam("owner");

//         // TODO pull assets from strategy

//         return super.redeem(shares, receiver, owner);
//     }

//     // ========== VIEW FUNCTIONS ========== //

//     function totalAssets() public view override returns (uint256) {
//         // We have to override this function to track assets deployed as collateral in the Morpho market in addition to local ones
//         uint256 local = IERC20(asset()).balanceOf(address(this));
//         uint256 deployed = morpho.collateral(cvMarket, address(this));
//         return local + deployed;
//     }

//     function currentRewards() public view returns (uint256) {
//         // Calculates the currently controlled balance rewards, not including those that were previously paid out
//         uint256 local = rewardToken.balanceOf(address(this));
//         uint256 deployed = morpho.expectedSupplyAssets(tokenMarket, address(this));
//         return local + deployed;
//     }

//     function totalRewards() public view returns (uint256) {
//         // Total rewards are current rewards plus those that have been paid out
//         return currentRewards() + paidRewards;
//     }

//     function currentHedgedBalance() public view returns (uint256) {
//         // Calculates the currently controlled balance of the hedged asset
//         return morpho.expectedBorrowAssets(cvMarket, address(this));
//     }

//     function currentYieldIndex() public view returns (uint256) {
//         // The Yield Index is a measure of the total profits earned by the vault
//         // It is a multiplicative index, which starts at 1.
//         // It is possible for the yield index to be negative (i.e. less than 1).
//         // We use fixed point math with 18 decimals to represent the yield index.
//         // Therefore, 1 = 1e18.

//         // The Yield Index is calculated as the sum of current and paid out reward token holdings
//         // divided by the value of the hedged (borrowed) asset in the vault (expressed in terms of the reward token).
//         // A positive yield index means that the reward token value is greater than the hedged asset value.
//         // A negative yield index means that the reward token value is less than the hedged asset value.

//         // Calculate the denominator
//         uint256 hedgedBalance = currentHedgedBalance();
//         uint256 tokenPrice = _getTokenPrice(); // TODO need to implement using UniswapV3 TWAP
//         uint256 totalHedged = hedgedBalance * tokenPrice / 10 ** hedgedToken.decimals();

//         // Calculate the yield index
//         return totalRewards() * 10 ** 18 / totalHedged;
//     }

//     function surplus() public view returns (uint256) {
//         // The surplus is the difference in value between the total rewards and the total hedged amount
//         // It is calculated as an amount of reward tokens
//         uint256 hedgedBalance = currentHedgedBalance();
//         uint256 tokenPrice = _getTokenPrice(); // TODO need to implement using UniswapV3 TWAP
//         uint256 totalHedged = hedgedBalance * tokenPrice / 10 ** hedgedToken.decimals();

//         return totalRewards() - totalHedged;
//     }

//     // ========== NON-TRANSFERABLE ========== //
//     // We disable transfers for the vault shares due to the way reward accounting works
//     // If enabled, a user could change another user's weighted index by sending them shares
//     // Mints and burns are

//     function transfer(address, uint256) public override returns (bool) {
//         revert NonTransferable();
//     }

//     function transferFrom(address, address, uint256) public override returns (bool) {
//         revert NonTransferable();
//     }

//     // ========== ADMIN ========== //
// }
