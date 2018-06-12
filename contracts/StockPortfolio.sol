pragma solidity ^0.4.23;

import "./Ownable.sol";

/**
  * @title StockPortfolio
  * @author aflesher
  * @dev StockPortfolio is smart contract for keeping a record
  * @dev stock purchases. Trades can more or less be validated
  * @dev using the trade timestamp and comparing the data to
  * @dev historical values.
  */
contract StockPortfolio is Ownable {

    struct Trade {
        bytes10 symbol;
        bool isSell;
        uint32 quantity;
        uint32 price;
        uint256 timestamp;
    }

    struct Split {
        bytes10 symbol;
        bool isReverse;
        uint8 spread;
        uint256 timestamp;
    }

    struct Position {
        uint32 quantity;
        uint32 avgPrice;
    }

    Trade[] private trades;
    Split[] private splits;
    mapping (bytes10 => Position) positions;
    bytes10[] private holdings;

    event Bought(bytes10 symbol, uint32 quantity, uint32 price);
    event Sold(bytes10 symbol, uint32 quantity, uint32 price, int64 profits);
    event ForwardSplit(bytes10 symbol, uint8 mulitple);
    event ReverseSplit(bytes10 symbol, uint8 divisor);

    int public profits;

    function () public payable {}

    /**
     * @dev Adds a new position/trade
     * @param _symbol A stock symbol
     * @param _quantity Quantity of shares to buy
     * @param _price Price per share * 100 ($10.24 = 1024)
     */
    function buy
    (
        bytes10 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        external
        onlyOwner
    {
        _buy(_symbol, _quantity, _price);
    }

    /**
     * @dev Adds a series of positions/trades
     * @param _symbols Stock symbols
     * @param _quantities Quantities of shares to buy
     * @param _prices Prices per share * 100 ($10.24 = 1024)
     */
    function bulkBuy
    (
        bytes10[] _symbols,
        uint32[] _quantities,
        uint32[] _prices
    )
        external
        onlyOwner
    {
        for (uint i = 0; i < _symbols.length; i++) {
            _buy(_symbols[i], _quantities[i], _prices[i]);
        }
    }

    /**
     * @dev Tracks a stock split
     * @param _symbol A stock symbol
     * @param _multiple Number of new shares per share created
     */
    function split
    (
        bytes10 _symbol,
        uint8 _multiple
    )
        external
        onlyOwner
    {
        Position storage position = positions[_symbol];
        require(position.quantity > 0);
        uint32 quantity = (_multiple * position.quantity) - position.quantity;
        _split(_symbol, false, _multiple);
        position.avgPrice = (position.quantity * position.avgPrice) / (position.quantity + quantity);
        position.quantity += quantity;

        emit ForwardSplit(_symbol, _multiple);
    }

    /**
     * @dev Tracks a reverse stock split
     * @param _symbol A stock symbol
     * @param _divisor Number of existing shares that will equal 1 new share
     * @param _price The current stock price. Remainder shares will sold at this price
     */
    function reverseSplit
    (
        bytes10 _symbol,
        uint8 _divisor,
        uint32 _price
    )
        external
        onlyOwner
    {
        Position storage position = positions[_symbol];
        require(position.quantity > 0);
        uint32 quantity = position.quantity / _divisor;
        uint32 extraQuantity = position.quantity - (quantity * _divisor);
        if (extraQuantity > 0) {
            _sell(_symbol, extraQuantity, _price);
        }
        _split(_symbol, true, _divisor);
        position.avgPrice = position.avgPrice * _divisor;
        position.quantity = quantity;

        emit ReverseSplit(_symbol, _divisor);
    }

    /**
     * @dev Sells a position, adds a new trade and adds profits/lossses
     * @param _symbol Stock symbol
     * @param _quantity Quantity of shares to sale
     * @param _price Price per share * 100 ($10.24 = 1024)
     */
    function sell
    (
        bytes10 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        external
        onlyOwner
    {
        _sell(_symbol, _quantity, _price);
    }

    /**
     * @dev Sells positions, adds a new trades and adds profits/lossses
     * @param _symbols Stock symbols
     * @param _quantities Quantities of shares to sale
     * @param _prices Prices per share * 100 ($10.24 = 1024)
     */
    function bulkSell
    (
        bytes10[] _symbols,
        uint32[] _quantities,
        uint32[] _prices
    )
        external
        onlyOwner
    {
        for (uint i = 0; i < _symbols.length; i++) {
            _sell(_symbols[i], _quantities[i], _prices[i]);
        }
    }

    function getTradesCount() public view returns(uint) {
        return trades.length;
    }

    function getTrade
    (
        uint _index
    )
        public
        view
        returns(
            bytes10 symbol,
            bool isSell,
            uint32 quantity,
            uint32 price,
            uint256 timestamp
        )
    {
        Trade storage trade = trades[_index];
        symbol = trade.symbol;
        isSell = trade.isSell;
        quantity = trade.quantity;
        price = trade.price;
        timestamp = trade.timestamp;
    }

    function getPosition
    (
        bytes10 _symbol
    )
        public
        view
        returns
        (
            uint32 quantity,
            uint32 avgPrice
        )
    {
        Position storage position = positions[_symbol];
        quantity = position.quantity;
        avgPrice = position.avgPrice;
    }

    function getPositionFromHolding
    (
        uint _index
    )
        public
        view
        returns
        (
            bytes10 symbol,
            uint32 quantity,
            uint32 avgPrice
        )
    {
        symbol = holdings[_index];
        Position storage position = positions[symbol];
        quantity = position.quantity;
        avgPrice = position.avgPrice;
    }

    function getHoldingsCount() public view returns(uint) {
        return holdings.length;
    }

    function getHolding(uint _index) public view returns(bytes10) {
        return holdings[_index];
    }

    function getSplitsCount() public view returns(uint) {
        return splits.length;
    }

    function getSplit
    (
        uint _index
    )
        public
        view
        returns(
            bytes10 symbol,
            bool isReverse,
            uint8 spread,
            uint256 timestamp
        )
    {
        Split storage aSplit = splits[_index];
        symbol = aSplit.symbol;
        isReverse = aSplit.isReverse;
        spread = aSplit.spread;
        timestamp = aSplit.timestamp;
    }

    function _addHolding
    (
        bytes10 _symbol
    )
        private
    {
        holdings.push(_symbol);
    }

    function _removeHolding
    (
        bytes10 _symbol
    )
        private
    {
        if (holdings.length == 0) {
            return;
        }
        bool found = false;
        for (uint i = 0; i < holdings.length; i++) {
            if (found) {
                holdings[i - 1] = holdings[i];
            }

            if (holdings[i] == _symbol) {
                found = true;
            }
        }
        if (found) {
            delete holdings[holdings.length - 1];
            holdings.length--;
        }
    }

    function _trade
    (
        bytes10 _symbol,
        bool _isSell,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        trades.push(
            Trade({
                symbol: _symbol,
                isSell: _isSell,
                quantity: _quantity,
                price: _price,
                timestamp: now
            })
        );
    }

    function _split
    (
        bytes10 _symbol,
        bool _isReverse,
        uint8 _spread
    )
        private
    {
        splits.push(
            Split({
                symbol: _symbol,
                isReverse: _isReverse,
                spread: _spread,
                timestamp: now
            })
        );
    }

    function _sell
    (
        bytes10 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        Position storage position = positions[_symbol];
        require(position.quantity >= _quantity);
        int64 profit = int64(_quantity * _price) - int64(_quantity * position.avgPrice);
        position.quantity -= _quantity;
        if (position.quantity <= 0) {
            _removeHolding(_symbol);
            delete positions[_symbol];
        }
        profits += profit;
        _trade(_symbol, true, _quantity, _price);
        emit Sold(_symbol, _quantity, _price, profit);
    }

    function _buy
    (
        bytes10 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        _trade(_symbol, false, _quantity, _price);
        Position storage position = positions[_symbol];
        if (position.quantity == 0) {
            _addHolding(_symbol);
        }
        position.avgPrice = ((position.quantity * position.avgPrice) + (_quantity * _price)) /
            (position.quantity + _quantity);
        position.quantity += _quantity;

        emit Bought(_symbol, _quantity, _price);
    }

}