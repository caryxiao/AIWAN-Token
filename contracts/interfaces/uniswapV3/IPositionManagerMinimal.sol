// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev 仅保留你在合约中用到的方法/结构体，签名需与 Uniswap v3-periphery 一致
interface IPositionManagerMinimal {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    // 你代码里用到了 ownerOf（来自 ERC721），也在这里声明一份，避免引入 0.7 的 IERC721
    function ownerOf(uint256 tokenId) external view returns (address);

    function mint(MintParams calldata params)
    external
    payable
    returns (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
    external
    returns (uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params)
    external
    returns (uint256 amount0, uint256 amount1);
}
