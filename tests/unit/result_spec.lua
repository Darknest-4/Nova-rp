local helpers = dofile('tests/helpers.lua')

describe('nova_lib :: Result', function()
    local Result

    before_each(function()
        Result = helpers.loadLib().Result
    end)

    it('sikeres eredményt csomagol', function()
        local result = Result.ok(42)
        assert.is_true(result:isOk())
        assert.is_false(result:isErr())
        assert.equals(42, result:unwrap())
    end)

    it('hibás eredményt kóddal és paraméterekkel hordoz', function()
        local result = Result.err('FEATURE_DISABLED', { feature = 'housing' })
        assert.is_true(result:isErr())
        assert.equals('FEATURE_DISABLED', result.code)
        assert.equals('housing', result.details.feature)
    end)

    it('nem enged üres hibakódot — a hiba mindig azonosítható legyen', function()
        assert.has_error(function() Result.err('') end)
        assert.has_error(function() Result.err(nil) end)
    end)

    it('unwrap() hibát dob hibás eredményen', function()
        local result = Result.err('NOT_FOUND')
        assert.has_error(function() result:unwrap() end)
    end)

    it('unwrapOr() alapértelmezettet ad hiba esetén', function()
        assert.equals('alap', Result.err('NOT_FOUND'):unwrapOr('alap'))
        assert.equals('érték', Result.ok('érték'):unwrapOr('alap'))
    end)

    it('map() csak sikeres eredményen fut le', function()
        local doubled = Result.ok(21):map(function(value) return value * 2 end)
        assert.equals(42, doubled:unwrap())

        local failed = Result.err('NOT_FOUND'):map(function() error('nem futhat le') end)
        assert.is_true(failed:isErr())
        assert.equals('NOT_FOUND', failed.code)
    end)

    it('andThen() láncol, és megköveteli a Result visszatérést', function()
        local chained = Result.ok(2):andThen(function(value)
            return Result.ok(value + 1)
        end)
        assert.equals(3, chained:unwrap())

        assert.has_error(function()
            Result.ok(1):andThen(function() return 'nem Result' end)
        end)
    end)

    it('felismeri a saját példányait', function()
        assert.is_true(Result.is(Result.ok(1)))
        assert.is_false(Result.is({ ok = true }))
        assert.is_false(Result.is(nil))
    end)
end)
