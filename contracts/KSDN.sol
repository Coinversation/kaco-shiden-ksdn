//SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DappsStaking.sol";

contract KSDN is ERC20, Ownable {
    uint public stakedSDN;

    uint public fee; //unit: 0.0001
    address public feeTo;

    uint public lastClaimedEra;
    DappsStaking public constant DAPPS_STAKING = DappsStaking(0x0000000000000000000000000000000000005001);
    address public constant KACO_ADDRESS = 0xcd8620889c1dA22ED228e6C00182177f9dAd16b7;
    uint public constant RATIO_PRECISION = 100000000; //precision: 0.00000001

    constructor(
        string memory name,
        string memory symbol,
        uint _fee,
        address _feeTo,
        uint _lastClaimedEra
    ) ERC20(name, symbol) {
        fee = _fee;
        feeTo = _feeTo;
        lastClaimedEra = _lastClaimedEra;
    }

    function getRatio() public view returns (uint){
        uint ksdnSupply = totalSupply();
        if(ksdnSupply == 0){
            return RATIO_PRECISION;
        }else{
            return stakedSDN * RATIO_PRECISION / ksdnSupply;
        }
    }

    function erasToClaim() public view returns (uint[] memory){
        uint currentEra = DAPPS_STAKING.read_current_era();
        uint toClaimEra = lastClaimedEra + 1;
        uint gap = currentEra - toClaimEra;
        uint[] memory gapEras = new uint[](gap);
        for(uint i = 0; i < gap; i++){
            gapEras[i] = toClaimEra;
            toClaimEra++;
        }
        return gapEras;
    }

    //return: the ratio before this deposit operation.
    function claimAndReinvest(uint depositSDN) internal returns (uint){
        uint[] memory gapEras = erasToClaim();
        if(gapEras.length > 0){
            for(uint i = 0; i < gapEras.length; i++){
                uint128 toClaimEra = uint128(gapEras[i]);
                DAPPS_STAKING.claim(KACO_ADDRESS, toClaimEra);
            }
            //todo: should call withdraw_unbonded?
            lastClaimedEra = gapEras[gapEras.length - 1];
        }
        uint _balance = address(this).balance;
        require(_balance >= depositSDN, "invalid depositSDN");
        if(_balance > 0){
            //todo: should transfer SDN to target first? {value:_balance}
            DAPPS_STAKING.bond_and_stake(KACO_ADDRESS, uint128(_balance));
            uint stakedAmount = DAPPS_STAKING.read_staked_amount(KACO_ADDRESS);
            require(stakedAmount >= stakedSDN + _balance, "invalid stakedAmount");
            stakedSDN = stakedAmount;

            uint ksdnSupply = totalSupply();
            uint ratio = RATIO_PRECISION;
            if(ksdnSupply > 0){
                ratio = (stakedAmount - depositSDN) * RATIO_PRECISION / ksdnSupply;
            }
            if(_balance - depositSDN > 0){
                _mint(feeTo, ((_balance - depositSDN) * fee / 10000 ) * RATIO_PRECISION / ratio); //mint fee
            }
            return ratio;
        }else{
            return getRatio();
        }
    }

    /**
     * @dev Allow a user to deposit underlying tokens and mint the corresponding number of wrapped tokens.
     */
    function depositFor(address account)
        external
        payable
    {
        uint ratio = claimAndReinvest(msg.value);
        if(msg.value > 0){
            _mint(account, msg.value * RATIO_PRECISION / ratio);
        }
    }

    /**
     * @dev Allow a user to burn a number of wrapped tokens and withdraw the corresponding number of underlying tokens.
     */
    function withdrawTo(address payable account, uint ksdnAmount)
        external
    {
        uint ratio = claimAndReinvest(0);
        _burn(_msgSender(), ksdnAmount);
        uint sdnAmount = ksdnAmount * ratio  / RATIO_PRECISION;
        require(sdnAmount <= type(uint128).max, "too large amount");
        DAPPS_STAKING.unbond_and_unstake(KACO_ADDRESS, uint128(sdnAmount));
        DAPPS_STAKING.withdraw_unbonded();
        uint _balance = address(this).balance;
        require(_balance >= sdnAmount, "not enough SDN");
        (bool sent, bytes memory data) = account.call{value: sdnAmount}("");
        require(sent, "Failed to send SDN");
    }

    function setFee(uint _fee, address _feeTo) external onlyOwner{
        fee = _fee;
        feeTo = _feeTo;
    }
}
