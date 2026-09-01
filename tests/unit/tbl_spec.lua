local helpers = dofile('tests/helpers.lua')

describe('nova_lib :: tbl', function()
    local tbl

    before_each(function()
        tbl = helpers.loadLib().tbl
    end)

    describe('isArray', function()
        it('felismeri a tömböket és a map-eket', function()
            assert.is_true(tbl.isArray({}))
            assert.is_true(tbl.isArray({ 'a', 'b' }))
            assert.is_false(tbl.isArray({ a = 1 }))
            assert.is_false(tbl.isArray({ [2] = 'a' }))
            assert.is_false(tbl.isArray('nem tábla'))
        end)
    end)

    describe('deepCopy', function()
        it('másolatot ad, nem hivatkozást', function()
            local source = { a = { b = { c = 1 } } }
            local copy = tbl.deepCopy(source)
            copy.a.b.c = 2
            assert.equals(1, source.a.b.c)
        end)

        it('ciklikus hivatkozáson nem akad végtelen ciklusba', function()
            local source = { name = 'ciklus' }
            source.self = source
            local copy = tbl.deepCopy(source)
            assert.equals('ciklus', copy.name)
            assert.equals(copy, copy.self)
        end)
    end)

    describe('deepMerge', function()
        it('rekurzívan fésül össze map-eket', function()
            local target = { db = { host = 'localhost', port = 3306 } }
            tbl.deepMerge(target, { db = { host = 'prod-db' } })
            assert.equals('prod-db', target.db.host)
            assert.equals(3306, target.db.port)
        end)

        it('tömböt lecserél, nem hozzáfűz', function()
            local target = { languages = { 'hu', 'en', 'de' } }
            tbl.deepMerge(target, { languages = { 'hu' } })
            assert.equals(1, #target.languages)
            assert.equals('hu', target.languages[1])
        end)

        it('nem hivatkozást másol be a forrásból', function()
            local source = { nested = { value = 1 } }
            local target = {}
            tbl.deepMerge(target, source)
            target.nested.value = 99
            assert.equals(1, source.nested.value)
        end)
    end)

    describe('flatten', function()
        it('pontokkal elválasztott kulcsokra bont', function()
            local flat = tbl.flatten({
                money = { received = '{amount} érkezett', spent = 'elköltve' },
            })
            assert.equals('{amount} érkezett', flat['money.received'])
            assert.equals('elköltve', flat['money.spent'])
        end)

        it('a tömböt levélértéknek tekinti', function()
            local flat = tbl.flatten({ config = { langs = { 'hu', 'en' } } })
            assert.is_table(flat['config.langs'])
            assert.equals('hu', flat['config.langs'][1])
        end)
    end)

    describe('get / set', function()
        it('útvonal mentén olvas', function()
            local source = { Economy = { Banking = { MaxTransfer = 1000000 } } }
            assert.equals(1000000, tbl.get(source, 'Economy.Banking.MaxTransfer'))
        end)

        it('hiányzó ágra nil-t ad, nem hibát', function()
            assert.is_nil(tbl.get({}, 'nincs.ilyen.ut'))
            assert.is_nil(tbl.get({ a = 'string' }, 'a.b.c'))
        end)

        it('útvonal mentén ír, közbenső ágakat létrehozva', function()
            local target = {}
            tbl.set(target, 'Features.Phone.Enabled', true)
            assert.is_true(target.Features.Phone.Enabled)
        end)
    end)

    it('sortedKeys determinisztikus sorrendet ad', function()
        local keys = tbl.sortedKeys({ zebra = 1, alma = 2, medve = 3 })
        assert.same({ 'alma', 'medve', 'zebra' }, keys)
    end)
end)
