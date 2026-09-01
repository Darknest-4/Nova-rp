local helpers = dofile('tests/helpers.lua')

describe('nova_lib :: schema', function()
    local schema

    before_each(function()
        schema = helpers.loadLib().schema
    end)

    ---Segéd: az első hiba kódja adott útvonalon.
    local function issueAt(result, path)
        for _, issue in ipairs(result.details.issues) do
            if issue.path == path then return issue end
        end
        return nil
    end

    it('érvényes értéket átenged', function()
        local result = schema.validate('hu', { type = 'string', enum = { 'hu', 'en', 'de' } })
        assert.is_true(result:isOk())
        assert.equals('hu', result:unwrap())
    end)

    it('típushibát jelez', function()
        local result = schema.validate('5000', { type = 'number' }, 'Economy.StartingCash')
        assert.is_true(result:isErr())
        local issue = issueAt(result, 'Economy.StartingCash')
        assert.equals('TYPE', issue.code)
        assert.equals('number', issue.expected)
        assert.equals('string', issue.got)
    end)

    it('különbséget tesz number és integer között', function()
        assert.is_true(schema.validate(3.5, { type = 'number' }):isOk())
        assert.is_true(schema.validate(3.5, { type = 'integer' }):isErr())
        assert.is_true(schema.validate(3, { type = 'integer' }):isOk())
    end)

    it('kötelező mező hiányát jelzi', function()
        local result = schema.validate(nil, { type = 'string' }, 'Server.Name')
        assert.equals('REQUIRED', issueAt(result, 'Server.Name').code)
    end)

    it('opcionális mező hiánya nem hiba', function()
        assert.is_true(schema.validate(nil, { type = 'string', optional = true }):isOk())
    end)

    it('alapértelmezett értéket helyettesít be', function()
        local result = schema.validate(nil, { type = 'number', default = 45 })
        assert.equals(45, result:unwrap())
    end)

    it('a tábla-alapértelmezésből másolatot ad, nem közös hivatkozást', function()
        local spec = { type = 'array', default = { 'hu' } }
        local first = schema.validate(nil, spec):unwrap()
        first[#first + 1] = 'en'
        local second = schema.validate(nil, spec):unwrap()
        assert.equals(1, #second)
    end)

    it('tartományt ellenőriz', function()
        local spec = { type = 'number', min = 0, max = 100 }
        assert.is_true(schema.validate(50, spec):isOk())
        assert.equals('RANGE', issueAt(schema.validate(-1, spec), '').code)
        assert.equals('RANGE', issueAt(schema.validate(101, spec), '').code)
    end)

    it('string hosszt és mintát ellenőriz', function()
        local spec = { type = 'string', minLen = 2, maxLen = 8, pattern = '^[a-z0-9_]+$' }
        assert.is_true(schema.validate('water_01', spec):isOk())
        assert.equals('LENGTH', issueAt(schema.validate('a', spec), '').code)
        assert.equals('PATTERN', issueAt(schema.validate('Water', spec), '').code)
    end)

    it('enum-on kívüli értéket elutasít', function()
        local result = schema.validate('fr', { type = 'string', enum = { 'hu', 'en' } })
        assert.equals('ENUM', issueAt(result, '').code)
    end)

    describe('beágyazott táblák', function()
        local spec = {
            type = 'table',
            fields = {
                host = { type = 'string' },
                port = { type = 'integer', default = 3306, min = 1, max = 65535 },
                pool = {
                    type = 'table',
                    fields = { limit = { type = 'integer', min = 1 } },
                },
            },
        }

        it('érvényes struktúrát átenged és kiegészít', function()
            local result = schema.validate({ host = 'db', pool = { limit = 20 } }, spec, 'Database')
            assert.is_true(result:isOk())
            local value = result:unwrap()
            assert.equals('db', value.host)
            assert.equals(3306, value.port)
            assert.equals(20, value.pool.limit)
        end)

        it('a hibát a teljes útvonallal jelzi', function()
            local result = schema.validate({ host = 'db', pool = { limit = 0 } }, spec, 'Database')
            assert.equals('RANGE', issueAt(result, 'Database.pool.limit').code)
        end)

        it('MINDEN hibát összegyűjt, nem áll meg az elsőnél', function()
            local result = schema.validate({ port = 'nem szám', pool = {} }, spec, 'Database')
            assert.is_true(#result.details.issues >= 3) -- host, port, pool.limit
        end)

        it('ismeretlen kulcsot elutasít (elgépelés-védelem)', function()
            local result = schema.validate(
                { host = 'db', prot = 3306, pool = { limit = 5 } }, spec, 'Database')
            assert.equals('UNKNOWN_KEY', issueAt(result, 'Database.prot').code)
        end)

        it('strict = false esetén megengedi az ismeretlen kulcsot', function()
            local relaxed = {
                type = 'table', strict = false,
                fields = { host = { type = 'string' } },
            }
            assert.is_true(schema.validate({ host = 'db', extra = 1 }, relaxed):isOk())
        end)
    end)

    describe('tömbök', function()
        local spec = {
            type = 'array', minLen = 1,
            items = { type = 'string', pattern = '^%a%a$' },
        }

        it('elemenként validál', function()
            assert.is_true(schema.validate({ 'hu', 'en' }, spec, 'Languages'):isOk())
            local result = schema.validate({ 'hu', 'x' }, spec, 'Languages')
            assert.equals('PATTERN', issueAt(result, 'Languages[2]').code)
        end)

        it('elemszámot ellenőriz', function()
            assert.equals('LENGTH', issueAt(schema.validate({}, spec, 'Languages'), 'Languages').code)
        end)

        it('a map-et nem fogadja el tömbként', function()
            local result = schema.validate({ a = 1 }, spec, 'Languages')
            assert.equals('TYPE', issueAt(result, 'Languages').code)
        end)
    end)

    it('describe() olvasható hibalistát ad', function()
        local result = schema.validate({ port = 'x' }, {
            type = 'table', fields = { port = { type = 'integer' } },
        }, 'Database')
        local text = schema.describe(result.details.issues)
        assert.is_true(text:find('Database.port', 1, true) ~= nil)
    end)
end)
