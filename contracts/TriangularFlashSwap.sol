// SPDX-License-Identifier: MIT
pragma solidity >=0.7.5;

import "hardhat/console.sol";

import "./libraries/SafeERC20.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";

// V3
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract TriangularFlashSwap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function fundContract(
        address _owner,
        address _token,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_owner, _token, _amount);
    }

    function getTokenBalance(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    function startArbitrage(
        address _tokenBorrow,
        uint256 _amount,
        address _token0,
        address _token1,
        address _factory,
        address _router,
        address _dummyToken,
        address _quoter
    ) external {
        require(
            _tokenBorrow != address(0),
            "Borrowing token address must be valid."
        );
        require(_amount > 0, "Borrowing amount must be larger than zero");
        require(_token0 != address(0), "Token0 address must be valid.");
        require(_token1 != address(0), "Token1 address must be valid.");
        require(_factory != address(0), "Factory address must be valid.");
        require(_router != address(0), "Router address must be valid.");

        IERC20(_tokenBorrow).safeApprove(address(_router), MAX_INT);
        IERC20(_token0).safeApprove(address(_router), MAX_INT);
        IERC20(_token1).safeApprove(address(_router), MAX_INT);

        address pool = IUniswapV3Factory(_factory).getPool(
            _tokenBorrow,
            _dummyToken,
            500
        );

        require(pool != address(0), "Pool for selected pair does not exist");

        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        bytes memory data = abi.encode(
            _tokenBorrow,
            _amount,
            msg.sender,
            _token0,
            _token1,
            _factory,
            _router,
            _quoter
        );

        IUniswapV3Pool(pool).flash(address(this), amount0Out, amount1Out, data);
    }

    function uniswapV3FlashCallback(
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata data
    ) external {
        executeArbitrage(_amount0, _amount1, data);
    }

    function executeArbitrage(
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) private {
        (
            address tokenBorrow,
            uint256 amount,
            address senderAddress,
            address token0,
            address token1,
            address factory,
            address router,
            address quoter
        ) = abi.decode(
                _data,
                (address, uint256, address, address, address, address, address)
            );

        address pool = getPool(msg.sender, factory);

        require(msg.sender == pool, "Pair contract didn't execute arbitrage.");
        // require(
        //     _sender == address(this),
        //     "Initiater didn't match this contract."
        // );

        uint256 repayAmount = getLoanAmount(amount);

        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        uint256 receivedAmount = executeTriangularTrades(
            tokenBorrow,
            token0,
            token1,
            loanAmount,
            factory,
            router,
            quoter
        );

        // require(
        //     checkProfitability(repayAmount, receivedAmount),
        //     "Arbitrage not profitable. Transaction reverted."
        // );

        // payOut(
        //     tokenBorrow,
        //     senderAddress,
        //     SafeMath.sub(receivedAmount, repayAmount)
        // );

        // payBackLoan(tokenBorrow, pair, repayAmount);
    }

    function executeTriangularTrades(
        address _tokenBorrow,
        address _token0,
        address _token1,
        uint256 _loanAmount,
        address _factory,
        address _router,
        address _quoter
    ) private returns (uint256) {
        uint256 trade1AcquiredCoin = placeTrade(
            _tokenBorrow,
            _token0,
            _loanAmount,
            _factory,
            _router,
            _quoter
        );
        // uint256 trade2AcquiredCoin = placeTrade(
        //     _token0,
        //     _token1,
        //     trade1AcquiredCoin,
        //     _factory,
        //     _router,
        //     _quoter
        // );
        // uint256 trade3AcquiredCoin = placeTrade(
        //     _token1,
        //     _tokenBorrow,
        //     trade2AcquiredCoin,
        //     _factory,
        //     _router,
        //     _quoter
        // );

        // return trade3AcquiredCoin;
        return 0;
    }

    function placeTrade(
        address _fromToken,
        address _toToken,
        uint256 _amountIn,
        address _factory,
        address _router,
        address _quoter
    ) private returns (uint256) {
        address pool = IUniswapV3Factory(_factory).getPool(
            _fromToken,
            _toToken,
            500
        );

        require(pool != address(0), "Pool for pair does not exist");

        // Calculate amount out
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRecquired = IQuoterV2(_quoter).quoteExactInputSingle(
            path[0],
            path[1],
            500,
            _amountIn,
            0
        );

        console.log(amountRecquired);

        // uint256 amountReceived = IUniswapV2Router01(_router)
        //     .swapExactTokensForTokens(
        //         _amountIn,
        //         amountRecquired,
        //         path,
        //         address(this),
        //         deadline
        //     )[1];

        // require(amountReceived > 0, "Aborted TX: Trade returned zero");
        // return amountReceived;
        return 0;
    }

    function getPool(address _sender, address _factory)
        private
        view
        returns (address)
    {
        address token0Pair = IUniswapV3Pool(_sender).token0();
        address token1Pair = IUniswapV3Pool(_sender).token1();
        return IUniswapV3Factory(_factory).getPool(token0Pair, token1Pair, 500);
    }

    function getLoanAmount(uint256 _amount) private pure returns (uint256) {
        return
            SafeMath.add(
                _amount,
                SafeMath.add(SafeMath.div(SafeMath.mul(_amount, 3), 977), 1)
            );
    }

    function payOut(
        address _tokenBorrow,
        address _senderAddress,
        uint256 _amount
    ) private {
        IERC20 payoutToken = IERC20(_tokenBorrow);
        payoutToken.transfer(_senderAddress, _amount);
    }

    function payBackLoan(
        address _tokenBorrow,
        address _pair,
        uint256 _repayAmount
    ) private {
        IERC20(_tokenBorrow).transfer(_pair, _repayAmount);
    }

    function checkProfitability(uint256 _input, uint256 _output)
        private
        pure
        returns (bool)
    {
        return _output > _input;
    }
}
