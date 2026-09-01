local helpers = dofile('tests/helpers.lua')

describe('nova_lib :: str', function()
    local str

    before_each(function()
        str = helpers.loadLib().str
    end)

    it('trim levágja a whitespace-t', function()
        assert.equals('NOVA', str.trim('   NOVA \t\n'))
        assert.equals('', str.trim('   '))
    end)

    it('split nyers elválasztó mentén vág', function()
        assert.same({ 'nova', 'admin', 'kick' }, str.split('nova.admin.kick', '.'))
        assert.same({ 'egy' }, str.split('egy', ','))
        assert.same({ '', 'a', '' }, str.split(',a,', ','))
    end)

    it('split üres elválasztóra hibát dob', function()
        assert.has_error(function() str.split('abc', '') end)
    end)

    it('startsWith / endsWith', function()
        assert.is_true(str.startsWith('nova.admin.kick', 'nova.'))
        assert.is_false(str.startsWith('nova.admin.kick', 'admin'))
        assert.is_true(str.endsWith('config.production.lua', '.lua'))
        assert.is_true(str.endsWith('bármi', ''))
    end)

    it('interpolate behelyettesíti a helyőrzőket', function()
        assert.equals('5000 Ft érkezett',
            str.interpolate('{amount} Ft érkezett', { amount = 5000 }))
    end)

    it('interpolate érintetlenül hagyja a hiányzó paramétert', function()
        -- Szándékos: a hiány legyen látható, ne néma üres string.
        assert.equals('{amount} Ft érkezett',
            str.interpolate('{amount} Ft érkezett', { other = 1 }))
    end)

    it('interpolate paraméterek nélkül változatlanul ad vissza', function()
        assert.equals('{amount}', str.interpolate('{amount}'))
    end)

    it('padRight adott szélességre tölt', function()
        assert.equals('db   ', str.padRight('db', 5))
        assert.equals('hosszabb', str.padRight('hosszabb', 3))
    end)
end)
