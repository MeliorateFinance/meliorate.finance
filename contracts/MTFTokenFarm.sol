pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Owned {
    address public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }
}

contract MTFTokenFarm is Owned {
	
	address public mtFinance = address;
	address public mtsToken = address;

	//initializing safe computations
    using SafeMath for uint;
    string public name = "MTF Staking Farm";
    //MTSToken public mtsToken;
	uint256 public totalStakes = 0;
    uint256 public totalDividends = 0;
    uint256 private scaledRemainder = 0;
    uint public round = 1;
    //address[] public stakers;
	 struct USER{
        uint256 stakedTokens;
        uint256 lastDividends;
        uint256 fromTotalDividend;
        uint round;
        uint256 remainder;
    }
    mapping (address => uint) public stakingBalance;
	mapping (address => uint) public hasClaimed;
	mapping (address => uint) public claimableReward;
	mapping(address => USER) stakers;
    mapping (uint => uint256) public payouts;   
	//daily return of investment in percentage
    uint public dailyROI=5;                         //100 = 1%
	 //tax rate for staking in percentage
    //tax rate for unstaking in percentage 
	uint256 unstakingTaxRate=20;
    uint256 stakingTaxRate=10;	
	//total amount of staked Token
    uint public totalStaked;
	uint private scaling = uint(10) ** 12;
	 /** @dev trigger notification of withdrawal
    * @param sender   address of msg.sender
    * @param request  users requested withdraw amount
    */
    event NotifyWithdrawal(address sender,uint request);
	event emitStaked(address staker, uint256 tokens, uint256 stakingTaxRate);
    event emitUnstaked(address staker, uint256 tokens, uint256 unstakingTaxRate);
    event emitPayout(uint256 round, uint256 tokens, address sender);
    event emitClaimReward(address staker, uint256 reward);
    constructor() public {
		        owner = msg.sender;
    }
	// ------------------------------------------------------------------------
    // Owners can send the funds to be distributed to stakers using this function, it will be distributed to stakers based on their total staked tokens
    // @param tokens number of tokens to distribute
    // ------------------------------------------------------------------------
    function addPayoutForStakers(uint256 tokens) external {
        _addPayout(tokens);
    }
	
	 // ------------------------------------------------------------------------
    // This will register payouts
    // ------------------------------------------------------------------------
    function _addPayout(uint256 tokens) private{
        uint256 available = (tokens.mul(scaling)).add(scaledRemainder); 
        uint256 dividendPerToken = available.div(totalStakes);
        scaledRemainder = available.mod(totalStakes);
        
        totalDividends = totalDividends.add(dividendPerToken);
        payouts[round] = payouts[round-1].add(dividendPerToken);
        
        emit emitPayout(round, tokens, msg.sender);
        round++;
    }
	
    // Stake MTF Tokens to the Staking Pool to earn staking rewards
    function stakeTokens(uint tokens) external  {
        require(IERC20(mtFinance).transferFrom(msg.sender, address(this), tokens), "Tokens cannot be transferred from users account");
        
        uint256 _stakingFee = 0;
        if(totalStakes > 0)
            _stakingFee= (calculatePercent(tokens).mul(stakingTaxRate)).div(10); 
        
        if(totalStakes > 0)
            // distribute the staking fee accumulated to other stakers before updating current user's stake
            _addPayout(_stakingFee);
            
        // add pending rewards to remainder to be claimed by user later, if there is any existing stake available
        uint256 owing = invokePendingReward(msg.sender);
        stakers[msg.sender].remainder += owing;
        
        stakers[msg.sender].stakedTokens = (tokens.sub(_stakingFee)).add(stakers[msg.sender].stakedTokens);
        stakers[msg.sender].lastDividends = owing;
        stakers[msg.sender].fromTotalDividend= totalDividends;
        stakers[msg.sender].round =  round;
        
        totalStakes = totalStakes.add(tokens.sub(_stakingFee));
		
		//hasClaimed[msg.sender] = false;
		
		claimableReward[msg.sender] = (claimableReward[msg.sender]).add(calculateMSPEarnings(msg.sender));
		
        emit emitStaked(msg.sender, tokens.sub(_stakingFee), _stakingFee);
    }
  
    function claimMSPRewards(uint totalReward)  public {
		
		require(totalReward > 0, 'Amount cannot zero');
		require(totalReward<=(stakers[msg.sender].stakedTokens ).mul(dailyROI), 'Amount cannot be greater than claimable balance');
		IERC20(mtsToken).transfer(msg.sender, totalReward);
		//calculates unpaid period
        //mark transaction date with remainder
		hasClaimed[msg.sender] = 1;
		emit NotifyWithdrawal(msg.sender,totalReward);	
	}
	
	function calculateMSPEarnings(address _stakeholder)  public view returns(uint) {
	
	    if(hasClaimed[_stakeholder]==0) {
           return (stakers[_stakeholder].stakedTokens ).mul(dailyROI);
        }else{
		    return 0;
		}
        
	}
   
     // ------------------------------------------------------------------------
    // Stakers can claim their pending rewards using this function,its advisable to claim the rewards before unstaking the tokens
    // ------------------------------------------------------------------------
    function claimStakingReward() public {
        if(totalDividends > stakers[msg.sender].fromTotalDividend){
            uint256 owing = invokePendingReward(msg.sender);
        
            owing = owing.add(stakers[msg.sender].remainder);
            stakers[msg.sender].remainder = 0;
        
            require(IERC20(mtFinance).transfer(msg.sender,owing), "ERROR: error in sending reward from contract");
        
            emit emitClaimReward(msg.sender, owing);
        
            stakers[msg.sender].lastDividends = owing; // unscaled
            stakers[msg.sender].round = round; // update the round
            stakers[msg.sender].fromTotalDividend = totalDividends; // scaled
        }
    }
	
	 // ------------------------------------------------------------------------
    // Get the pending rewards to be claimed by the staker
    // @param _staker the address of the staker
    // ------------------------------------------------------------------------    
    function invokePendingReward(address staker) private returns (uint256) {
        uint256 amount =  ((totalDividends.sub(payouts[stakers[staker].round - 1])).mul(stakers[staker].stakedTokens)).div(scaling);
        stakers[staker].remainder += ((totalDividends.sub(payouts[stakers[staker].round - 1])).mul(stakers[staker].stakedTokens)) % scaling ;
        return amount;
    }
    
    function fetchPendingReward(address staker) public view returns(uint256 _pendingReward) {
        uint256 amount =  ((totalDividends.sub(payouts[stakers[staker].round - 1])).mul(stakers[staker].stakedTokens)).div(scaling);
        amount += ((totalDividends.sub(payouts[stakers[staker].round - 1])).mul(stakers[staker].stakedTokens)) % scaling ;
        return (amount + stakers[staker].remainder);
    }
    // ------------------------------------------------------------------------
    // Stakers can un stake the staked tokens using this function, its advisable to claim your rewards before unstaking
    // @param tokens the number of tokens to withdraw
    // ------------------------------------------------------------------------
    function unstakeFromPool(uint256 tokens) external {
        
        require(stakers[msg.sender].stakedTokens >= tokens && tokens > 0, "Invalid token amount to withdraw");
        
        uint256 _unstakingFee = (calculatePercent(tokens).mul(unstakingTaxRate)).div(10);
        
        // add pending rewards to remainder to be claimed by user later, if there is any existing stake
        uint256 owing = invokePendingReward(msg.sender);
        stakers[msg.sender].remainder += owing;
                
        require(IERC20(mtFinance).transfer(msg.sender, tokens.sub(_unstakingFee)), "Error in un-staking tokens");
        
        stakers[msg.sender].stakedTokens = stakers[msg.sender].stakedTokens.sub(tokens);
        stakers[msg.sender].lastDividends = owing;
        stakers[msg.sender].fromTotalDividend= totalDividends;
        stakers[msg.sender].round =  round;
        
        totalStakes = totalStakes.sub(tokens);
        
        if(totalStakes > 0)
            _addPayout(_unstakingFee);           
		hasClaimed[msg.sender] = 1;
        emit emitUnstaked(msg.sender, tokens.sub(_unstakingFee), _unstakingFee);
    }
	
	// ------------------------------------------------------------------------
    // Get the number of tokens staked by a staker
    // @param _staker the address of the staker
    // ------------------------------------------------------------------------
    function yourStakedTokens(address staker) external view returns(uint256 stakedToken){
        return stakers[staker].stakedTokens;
    }
    
    // ------------------------------------------------------------------------
    // Get the MTF balance of the token holder
    // @param user the address of the token holder
    // ------------------------------------------------------------------------
    function yourMTFBalance(address user) external view returns(uint256 mtfBalance){
        return IERC20(mtFinance).balanceOf(user);
    }
	//sets the staking rate
    function setStakingTaxRate(uint _stakingTaxRate) external onlyOwner() {
        stakingTaxRate = _stakingTaxRate;
    }

    //sets the unstaking rate
    function setUnstakingTaxRate(uint _unstakingTaxRate) external onlyOwner() {
        unstakingTaxRate = _unstakingTaxRate;
    }
    
    //sets the daily ROI
    function setDailyROI(uint _dailyROI) external onlyOwner() {
        dailyROI = _dailyROI;
    }
	
	//used to view the current reward pool
    function rewardPool() external view onlyOwner() returns(uint claimable) {
        return (IERC20(mtFinance).balanceOf(address(this))).sub(totalStaked);
    }
	// ------------------------------------------------------------------------
    // Private function to calculate the percentage
    // ------------------------------------------------------------------------
    function calculatePercent(uint256 _tokens) private returns (uint256){
        uint onePercentofTokens = _tokens.mul(100).div(100 * 10**uint(2));
        return onePercentofTokens;
    }
	
contract ClaimMTFToken {
    function balanceOf(address _owner) constant public returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
	}
	
	function withdrawForeignTokens(address _tokenContract) onlyOwner public returns (bool) {
		ClaimMTFToken token = ClaimMTFToken(_tokenContract);
		uint256 amount = token.balanceOf(address(this));
		return token.transfer(msg.sender, amount);
	}
	
}