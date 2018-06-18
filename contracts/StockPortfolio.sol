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
        bytes6 symbol;
        bool isSell;
        uint8 marketIndex;
        uint32 quantity;
        uint32 price;
        uint256 timestamp;
    }

    struct Split {
        bytes6 symbol;
        bool isReverse;
        uint8 marketIndex;
        uint8 spread;
        uint256 timestamp;
    }

    struct Position {
        uint32 quantity;
        uint32 avgPrice;
    }

    Trade[] private trades;
    Split[] private splits;
    mapping (bytes12 => Position) positions;
    bytes12[] private holdings;
    bytes6[] private markets;

    event Bought(bytes6 market, bytes6 symbol, uint32 quantity, uint32 price);
    event Sold(bytes6 market, bytes6 symbol, uint32 quantity, uint32 price, int64 profits);
    event ForwardSplit(bytes6 market, bytes6 symbol, uint8 mulitple);
    event ReverseSplit(bytes6 market, bytes6 symbol, uint8 divisor);

    mapping (bytes6 => int) public profits;

    constructor () public {
        markets.push(0x6e7973650000); //nyse 0
        markets.push(0x6e6173646171); //nasdaq 1
        markets.push(0x747378000000); //tsx 2
        markets.push(0x747378760000); //tsxv 3
        markets.push(0x6f7463000000); //otc 4
        markets.push(0x637365000000); //cse 5
    }

    function () public payable {}

    /**
     * @dev Adds a new position/trade
     * @param _symbol A stock symbol
     * @param _quantity Quantity of shares to buy
     * @param _price Price per share * 100 ($10.24 = 1024)
     */
    function buy
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        external
        onlyOwner
    {
        _buy(_marketIndex, _symbol, _quantity, _price);
    }

    /**
     * @dev Adds a series of positions/trades
     * @param _symbols Stock symbols
     * @param _quantities Quantities of shares to buy
     * @param _prices Prices per share * 100 ($10.24 = 1024)
     */
    function bulkBuy
    (
        uint8[] _marketIndexes,
        bytes6[] _symbols,
        uint32[] _quantities,
        uint32[] _prices
    )
        external
        onlyOwner
    {
        for (uint i = 0; i < _symbols.length; i++) {
            _buy(_marketIndexes[i], _symbols[i], _quantities[i], _prices[i]);
        }
    }

    /**
     * @dev Tracks a stock split
     * @param _symbol A stock symbol
     * @param _multiple Number of new shares per share created
     */
    function split
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        uint8 _multiple
    )
        external
        onlyOwner
    {
        bytes6 market = markets[_marketIndex];
        bytes12 stockKey = getStockKey(market, _symbol);
        Position storage position = positions[stockKey];
        require(position.quantity > 0);
        uint32 quantity = (_multiple * position.quantity) - position.quantity;
        _split(_marketIndex, _symbol, false, _multiple);
        position.avgPrice = (position.quantity * position.avgPrice) / (position.quantity + quantity);
        position.quantity += quantity;

        emit ForwardSplit(market, _symbol, _multiple);
    }

    /**
     * @dev Tracks a reverse stock split
     * @param _symbol A stock symbol
     * @param _divisor Number of existing shares that will equal 1 new share
     * @param _price The current stock price. Remainder shares will sold at this price
     */
    function reverseSplit
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        uint8 _divisor,
        uint32 _price
    )
        external
        onlyOwner
    {
        bytes6 market = markets[_marketIndex];
        bytes12 stockKey = getStockKey(market, _symbol);
        Position storage position = positions[stockKey];
        require(position.quantity > 0);
        uint32 quantity = position.quantity / _divisor;
        uint32 extraQuantity = position.quantity - (quantity * _divisor);
        if (extraQuantity > 0) {
            _sell(_marketIndex, _symbol, extraQuantity, _price);
        }
        _split(_marketIndex, _symbol, true, _divisor);
        position.avgPrice = position.avgPrice * _divisor;
        position.quantity = quantity;

        emit ReverseSplit(market, _symbol, _divisor);
    }

    /**
     * @dev Sells a position, adds a new trade and adds profits/lossses
     * @param _symbol Stock symbol
     * @param _quantity Quantity of shares to sale
     * @param _price Price per share * 100 ($10.24 = 1024)
     */
    function sell
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        external
        onlyOwner
    {
        _sell(_marketIndex, _symbol, _quantity, _price);
    }

    /**
     * @dev Sells positions, adds a new trades and adds profits/lossses
     * @param _symbols Stock symbols
     * @param _quantities Quantities of shares to sale
     * @param _prices Prices per share * 100 ($10.24 = 1024)
     */
    function bulkSell
    (
        uint8[] _marketIndexes,
        bytes6[] _symbols,
        uint32[] _quantities,
        uint32[] _prices
    )
        external
        onlyOwner
    {
        for (uint i = 0; i < _symbols.length; i++) {
            _sell(_marketIndexes[i], _symbols[i], _quantities[i], _prices[i]);
        }
    }

    function getMarketsCount() public view returns(uint) {
        return markets.length;
    }

    function getMarket(uint _index) public view returns(bytes6) {
        return markets[_index];
    }

    function getProfits(bytes6 _market) public view returns(int) {
        return profits[_market];
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
            bytes6 market,
            bytes6 symbol,
            bool isSell,
            uint32 quantity,
            uint32 price,
            uint256 timestamp
        )
    {
        Trade storage trade = trades[_index];
        market = markets[trade.marketIndex];
        symbol = trade.symbol;
        isSell = trade.isSell;
        quantity = trade.quantity;
        price = trade.price;
        timestamp = trade.timestamp;
    }

    function getPosition
    (
        bytes12 _stockKey
    )
        public
        view
        returns
        (
            uint32 quantity,
            uint32 avgPrice
        )
    {
        Position storage position = positions[_stockKey];
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
            bytes6 market, 
            bytes6 symbol,
            uint32 quantity,
            uint32 avgPrice
        )
    {
        bytes12 stockKey = holdings[_index];
        (market, symbol) = recoverStockKey(stockKey);
        Position storage position = positions[stockKey];
        quantity = position.quantity;
        avgPrice = position.avgPrice;
    }

    function getHoldingsCount() public view returns(uint) {
        return holdings.length;
    }

    function getHolding(uint _index) public view returns(bytes12) {
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
            bytes12 symbol,
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

    function getStockKey(bytes6 _market, bytes6 _symbol) public pure returns (bytes12 key) {
        bytes memory combined = new bytes(12);
        for (uint i = 0; i < 6; i++) {
            combined[i] = _market[i];
        }
        for (uint j = 0; j < 6; j++) {
            combined[j + 6] = _symbol[j];
        }
        assembly {
            key := mload(add(combined, 32))
        }
    }
    
    function recoverStockKey(bytes12 _key) public pure returns(bytes6 market, bytes6 symbol) {
        bytes memory _market = new bytes(6);
        bytes memory _symbol = new bytes(6);
        for (uint i = 0; i < 6; i++) {
            _market[i] = _key[i];
        }
        for (uint j = 0; j < 6; j++) {
            _symbol[j] = _key[j + 6];
        }
        assembly {
            market := mload(add(_market, 32))
            symbol := mload(add(_symbol, 32))
        }
    }

    function addMarket(bytes6 _market) public onlyOwner {
        markets.push(_market);
    }

    function _addHolding
    (
        bytes12 _stockKey
    )
        private
    {
        holdings.push(_stockKey);
    }

    function _removeHolding
    (
        bytes12 _stockKey
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

            if (holdings[i] == _stockKey) {
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
        uint8 _marketIndex,
        bytes6 _symbol,
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
                marketIndex: _marketIndex,
                quantity: _quantity,
                price: _price,
                timestamp: now
            })
        );
    }

    function _split
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        bool _isReverse,
        uint8 _spread
    )
        private
    {
        splits.push(
            Split({
                symbol: _symbol,
                isReverse: _isReverse,
                marketIndex: _marketIndex,
                spread: _spread,
                timestamp: now
            })
        );
    }

    function _sell
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        bytes6 market = markets[_marketIndex];
        bytes12 stockKey = getStockKey(market, _symbol);
        Position storage position = positions[stockKey];
        require(position.quantity >= _quantity);
        int64 profit = int64(_quantity * _price) - int64(_quantity * position.avgPrice);
        position.quantity -= _quantity;
        if (position.quantity <= 0) {
            _removeHolding(stockKey);
            delete positions[stockKey];
        }
        profits[market] += profit;
        _trade(_marketIndex, _symbol, true, _quantity, _price);
        emit Sold(market, _symbol, _quantity, _price, profit);
    }

    function _buy
    (
        uint8 _marketIndex,
        bytes6 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        bytes6 market = markets[_marketIndex];
        bytes12 stockKey = getStockKey(market, _symbol);
        _trade(_marketIndex, _symbol, false, _quantity, _price);
        Position storage position = positions[stockKey];
        if (position.quantity == 0) {
            _addHolding(stockKey);
        }
        position.avgPrice = ((position.quantity * position.avgPrice) + (_quantity * _price)) /
            (position.quantity + _quantity);
        position.quantity += _quantity;

        emit Bought(market, _symbol, _quantity, _price);
    }

}