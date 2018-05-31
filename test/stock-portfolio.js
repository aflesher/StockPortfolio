var StockPortfolio = artifacts.require('StockPortfolio'),
  _ = require('lodash');

contract('StockPortfolio', async (accounts) => {
  var sp;

  beforeEach('deploy new contract', async () => {
    sp = await StockPortfolio.new();
  });

  it('should add holdings', async () => {
    let stock = {
      symbol: 'AAPL',
      quantity: 10,
      price: 187.50
    };

    await sp.buy(web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    let position = await sp.getPosition(web3.toHex(stock.symbol));
    assert.equal(position[0].toNumber(), stock.quantity, 'quantity set');
    assert.equal(position[1].toNumber(), stock.price * 100, 'price set');

    let trade = await sp.getTrade(0);
    assert.equal(web3.toAscii(trade[0]).replace(/\u0000/g, ''), stock.symbol, 'symbol');
    assert.isFalse(trade[1], 'is not a sell');
    assert.equal(trade[2].toNumber(), stock.quantity, 'quantity');
    assert.equal(trade[3].toNumber(), stock.price * 100, 'price');

    let holding = await sp.getHolding(0);
    assert.equal(web3.toAscii(holding).replace(/\u0000/g, ''), stock.symbol, 'symbol');
  });

  it('should track sells', async () => {
    let buy = {
      symbol: 'AAPL',
      quantity: 10,
      price: 187.50
    };

    let sell = {
      symbol: 'AAPL',
      quantity: 10,
      price: 287.50
    }

    await sp.buy(web3.toHex(buy.symbol), buy.quantity, buy.price * 100);
    await sp.sell(web3.toHex(sell.symbol), sell.quantity, sell.price * 100);

    let position = await sp.getPosition(web3.toHex(sell.symbol));
    assert.equal(position[0].toNumber(), 0, 'quantity set');
    assert.equal(position[1].toNumber(), 0, 'price set');

    let trade = await sp.getTrade(1);
    assert.equal(web3.toAscii(trade[0]).replace(/\u0000/g, ''), sell.symbol, 'symbol');
    assert.isTrue(trade[1], 'is a sell');
    assert.equal(trade[2].toNumber(), sell.quantity, 'quantity');
    assert.equal(trade[3].toNumber(), sell.price * 100, 'price');
  });

  it('should track profits', async () => {
    let buy = {
      symbol: 'AAPL',
      quantity: 10,
      price: 187.50
    };

    let sell = {
      symbol: 'AAPL',
      quantity: 10,
      price: 287.50
    }

    await sp.buy(web3.toHex(buy.symbol), buy.quantity, buy.price * 100);
    await sp.sell(web3.toHex(sell.symbol), sell.quantity, sell.price * 100);
    let expectedProfits = (sell.quantity * sell.price) - (buy.quantity * buy.price);
    let profits = await sp.profits.call();
    assert.equal(Math.round(profits.toNumber() / 100), expectedProfits, 'profits');

    let buy2 = {
      symbol: 'NTDOY',
      quantity: 8,
      price: 51.31
    };

    let sell2 = {
      symbol: 'NTDOY',
      quantity: 4,
      price: 24.50
    }

    expectedProfits += ((sell2.quantity * sell2.price) - (sell2.quantity * buy2.price));
    await sp.buy(web3.toHex(buy2.symbol), buy2.quantity, buy2.price * 100);
    await sp.sell(web3.toHex(sell2.symbol), sell2.quantity, sell2.price * 100);
    let profits2 = await sp.profits.call();
    assert.equal(profits2.toNumber() / 100, expectedProfits, 'profits');

    let buy3 = {
      symbol: 'DS.V',
      quantity: 8000,
      price: .20
    };

    let sell3 = {
      symbol: 'DS.V',
      quantity: 8000,
      price: .01
    }

    expectedProfits += ((sell3.quantity * sell3.price) - (sell3.quantity * buy3.price));
    await sp.buy(web3.toHex(buy3.symbol), buy3.quantity, buy3.price * 100);
    await sp.sell(web3.toHex(sell3.symbol), sell3.quantity, sell3.price * 100);
    let profits3 = await sp.profits.call();
    assert.equal(profits3.toNumber() / 100, expectedProfits, 'negative profits');
  });  
});