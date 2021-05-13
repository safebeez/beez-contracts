// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./SafeMath.sol";
import "./IBEP20.sol";
import "./SafeBEP20.sol";
import "./Ownable.sol";
import "./HoneyToken.sol";

// MasterChef is the master of Hny. He can make Hny and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once HNY is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of HNYs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accHnyPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accHnyPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. HNYs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that HNYs distribution occurs.
        uint256 accHnyPerShare;   // Accumulated HNYs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The HNY TOKEN!
    HoneyComb public hnycmb;
    // Dev address.
    address public devaddr1;
    address public devaddr2;
    address public devadrr3;
    address public devadrr4; 			// 0x70997F35a7EFD317B73670cf849D6E1981276799
    // HNY tokens created per block.
    uint256 public hnycmbPerBlock;
    // Bonus muliplier for early hnycmb makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address					// 0x40b6fED9731Dc932801DFEaCD3d00dd607360D07
    address public feeAddress; 				

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when HNY mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        HoneyComb _hnycmb,
        address _devaddr1,
		address _devaddr2,
		address _devadrr3,
		address _devadrr4,
        address _feeAddress,
        uint256 _hnycmbPerBlock,
        uint256 _startBlock
    ) public {
        hnycmb = _hnycmb;
        devaddr1 = _devaddr1;
		devaddr2 = _devaddr2;
		devadrr3 = _devadrr3;
		devadrr4 = _devadrr4;
        feeAddress = _feeAddress;
        hnycmbPerBlock = _hnycmbPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accHnyPerShare: 0,
            depositFeeBP: _depositFeeBP
        }));
    }




    // Update the given pool's HNY allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending HNYs on frontend.
    function pendingHny(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accHnyPerShare = pool.accHnyPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 hnycmbReward = multiplier.mul(hnycmbPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accHnyPerShare = accHnyPerShare.add(hnycmbReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accHnyPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 hnycmbReward = multiplier.mul(hnycmbPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        hnycmb.mint(devaddr1, hnycmbReward.div(50));
        hnycmb.mint(devaddr2, hnycmbReward.div(50));
        hnycmb.mint(devadrr3, hnycmbReward.div(50));
        hnycmb.mint(devadrr4, hnycmbReward.div(50));
        hnycmb.mint(address(this), hnycmbReward);
        pool.accHnyPerShare = pool.accHnyPerShare.add(hnycmbReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for HNYCMB allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accHnyPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeHnyTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFeeBP > 0){
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            }else{
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accHnyPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accHnyPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeHnyTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accHnyPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe hnycmb transfer function, just in case if rounding error causes pool to not have enough HNYs.
    function safeHnyTransfer(address _to, uint256 _amount) internal {
        uint256 hnycmbBal = hnycmb.balanceOf(address(this));
        if (_amount > hnycmbBal) {
            hnycmb.transfer(_to, hnycmbBal);
        } else {
            hnycmb.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev1(address _devaddr1) public {
        require(msg.sender == devaddr1, "dev: wut?");
        devaddr1 = _devaddr1;
    }

    // Update dev address by the previous dev.
    function dev2(address _devaddr2) public {
        require(msg.sender == devaddr2, "dev: wut?");
        devaddr2 = _devaddr2;
    }

    // Update marketing address by the previous marketer.
    function dev3(address _devadrr3) public {
        require(msg.sender == devadrr3, "dev: wut?");
        devadrr3 = _devadrr3;
    }
    // Update dev address by the previous dev.
    function dev4(address _devadrr4) public {
        require(msg.sender == devadrr4, "dev: wut?");
        devadrr4 = _devadrr4;
    }

    function setFeeAddress(address _feeAddress) public{
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _hnycmbPerBlock) public onlyOwner {
        massUpdatePools();
        hnycmbPerBlock = _hnycmbPerBlock;
    }
}