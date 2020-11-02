const MTFinance = artifacts.require('MTFinance');

contract('MTFinance', accounts => {
    const totalSupply = 100000;
    const admin = accounts[0];
    let token;
    let tokensAvailable = totalSupply;

    before(async () => {
        token = await MTFinance.new("MTFinance", "MTF", 18, totalSupply);
    });

    it('Smart contract is deployed with correct values', async () => {
        let name = await token.name.call();
        let symbol = await token.symbol.call();
        let totalSupply = await token.totalSupply.call();
        assert.equal(name, 'MTFinance', 'Correct token name');
        assert.equal(symbol, 'MTF', 'Correct token symbol');
        assert.equal(totalSupply, totalSupply, 'Correct total supply');
    });

    it('Transfer tokens exceeding balance', async () => {
        const recipient = accounts[1];
        let f;

        try {
            await token.transfer.call(recipient, totalSupply + 1, {from: admin});
        } catch(e) {
            f = () => {throw e};
        } finally {
            assert.throws(f, /transfer amount exceeds balance/, 'Cannot transfer tokens exceeding balance');
        }
    });

    it('Transfer tokens properly', async () => {
        const recipient = accounts[1];
        const amount = 20;

        let senderBalance = await token.balanceOf(admin);
        let recipientBalance = await token.balanceOf(recipient);
        assert.equal(senderBalance.toNumber(), totalSupply, 'Correct token balance of the sender account');
        assert.equal(recipientBalance.toNumber(), 0, 'Correct token balance of the recipient account');
        
        let transfer = await token.transfer(recipient, amount, {from: admin});
        assert.isTrue(transfer.receipt.status, 'Transferred successfully');
        assert.equal(transfer.logs[0].args.from, admin, 'Correct sender account');
        assert.equal(transfer.logs[0].args.to, recipient, 'Correct recipient account');
        assert.equal(transfer.logs[0].args.value.toNumber(), amount, 'Correct transfer amount');

        tokensAvailable -= amount;

        let senderBalanceAfter = await token.balanceOf(admin);
        let recipientBalanceAfter = await token.balanceOf(recipient);
        assert.equal(senderBalanceAfter.toNumber(), tokensAvailable, 'Correct token balance of the sender account after transfer');
        assert.equal(recipientBalanceAfter.toNumber(), amount, 'Correct token balance of the recipient account after transfer');
    });

    it('Authorized spender transfers tokens exceeding allowance', async () => {
        const spender = accounts[2];
        const recipient = accounts[3];
        const amount = 10;

        let approval = await token.approve(spender, amount, {from: admin});
        assert.isTrue(approval.receipt.status, 'Approved successfully');
        assert.equal(approval.logs[0].args.owner, admin, 'Correct owner account');
        assert.equal(approval.logs[0].args.spender, spender, 'Correct spender account');
        assert.equal(approval.logs[0].args.value.toNumber(), amount, 'Correct transfer amount authorized to spender');

        let allowance = await token.allowance(admin, spender);
        assert.equal(allowance.toNumber(), amount, 'Correct allowance for delegated transfer');

        let f;

        try {
            await token.transferFrom(admin, recipient, 11, {from: spender});
        } catch(e) {
            f = () => {throw e};
        } finally {
            assert.throws(f, /transfer amount exceeds allowance/, 'Cannot transfer tokens exceeding allowance');
        }
    });

    it('Authorized spender transfers tokens properly', async () => {
        const spender = accounts[4];
        const recipient = accounts[5];
        const amount = 10;

        let approval = await token.approve(spender, amount, {from: admin});
        assert.isTrue(approval.receipt.status, 'Approved successfully');
        assert.equal(approval.logs[0].args.owner, admin, 'Correct owner account');
        assert.equal(approval.logs[0].args.spender, spender, 'Correct spender account');
        assert.equal(approval.logs[0].args.value.toNumber(), amount, 'Correct transfer amount authorized to spender');

        let allowance = await token.allowance(admin, spender);
        assert.equal(allowance.toNumber(), amount, 'Correct allowance for delegated transfer');

        let ownerBalance = await token.balanceOf(admin);
        let recipientBalance = await token.balanceOf(recipient);
        assert.equal(ownerBalance.toNumber(), tokensAvailable, 'Correct token balance of the owner account');
        assert.equal(recipientBalance.toNumber(), 0, 'Correct token balance of the recipient account');

        let transferFrom = await token.transferFrom(admin, recipient, amount, {from: spender});
        assert.isTrue(transferFrom.receipt.status, 'Transferred successfully');
        assert.equal(transferFrom.logs[0].args.from, admin, 'Correct owner account');
        assert.equal(transferFrom.logs[0].args.to, recipient, 'Correct recipient account');
        assert.equal(transferFrom.logs[0].args.value.toNumber(), amount, 'Correct transfer amount');

        tokensAvailable -= amount;

        let ownerBalanceAfter = await token.balanceOf(admin);
        let recipientBalanceAfter = await token.balanceOf(recipient);
        assert.equal(ownerBalanceAfter.toNumber(), tokensAvailable, 'Correct token balance of the owner account after transfer');
        assert.equal(recipientBalanceAfter.toNumber(), amount, 'Correct token balance of the recipient account after transfer');
    });
});
