--[[
    Ez a spec a SPIKE bizonyítéka: olyan modult tesztel, amely CitizenFX
    natívokat hív (GetConvar, GetConvarInt), FXServer elindítása nélkül.
]]

local helpers = dofile('tests/helpers.lua')
local cfx = dofile('tests/mocks/cfx.lua')

describe('nova_lib :: env (CFX natívokkal, mock ellen)', function()
    local env

    before_each(function()
        cfx.install()
        cfx.reset()
        env = helpers.loadLib().env
    end)

    it('szöveges convart olvas, alapértelmezéssel', function()
        cfx.setConvar('nova:environment', 'production')
        assert.equals('production', env.string('nova:environment', 'development'))
        assert.equals('development', env.string('nova:missing', 'development'))
    end)

    it('egész convart olvas', function()
        cfx.setConvar('nova:db:poolLimit', 20)
        assert.equals(20, env.int('nova:db:poolLimit', 10))
        assert.equals(10, env.int('nova:nincs', 10))
    end)

    it('logikai convart többféle írásmóddal ért', function()
        for _, truthy in ipairs({ 'true', '1', 'yes', 'on', 'TRUE' }) do
            cfx.setConvar('nova:feature', truthy)
            assert.is_true(env.bool('nova:feature', false))
        end
        cfx.setConvar('nova:feature', 'false')
        assert.is_false(env.bool('nova:feature', true))
        assert.is_true(env.bool('nova:nincs', true))
    end)

    it('hiányzó titkot hibaként ad vissza, nem crashel', function()
        local result = env.required('nova:db:password')
        assert.is_true(result:isErr())
        assert.equals('MISSING_CONVAR', result.code)
        assert.equals('nova:db:password', result.details.key)
    end)

    it('meglévő titkot sikerként ad vissza', function()
        cfx.setConvar('nova:db:password', 'titkos')
        assert.equals('titkos', env.required('nova:db:password'):unwrap())
    end)

    it('maszkolja a titkot naplózáshoz', function()
        local masked = env.mask('szuperTitkosJelszo')
        assert.equals('szu', masked:sub(1, 3))
        assert.is_nil(masked:find('Titkos', 1, true))
        assert.equals('<üres>', env.mask(nil))
        assert.equals('***', env.mask('abc'))
    end)
end)
