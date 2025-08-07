// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {AwMemeToken} from "../contracts/AwMemeToken.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";

contract DeployAwMemeToken is Script {
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    uint256 constant POOL_FEE = 3000; // 0.3%

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy AwMemeToken
        AwMemeToken awMemeToken = AwMemeToken(payable(
            Upgrades.deployUUPSProxy(
                "AwMemeToken.sol:AwMemeToken",
                abi.encodeCall(
                    AwMemeToken.initialize,
                    (
                        deployer, // 初始所有者
                        UNISWAP_V3_ROUTER, // uniswap v3 路由器
                        UNISWAP_V3_FACTORY, // uniswap v3 工厂
                        UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER, // uniswap v3 非同质化代币管理器
                        deployer, // 手续费钱包地址暂时设置为部署者地址
                        POOL_FEE // 池子手续费
                    )
                )
            )
        ));

        int24 tick = 69315;
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        // 创建池子
        awMemeToken.createPool(sqrtPriceX96);

        vm.stopBroadcast();
    }
}
