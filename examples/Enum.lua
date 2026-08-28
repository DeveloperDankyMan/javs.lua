local _javs = require(game:GetService("ServerStorage"):WaitForChild("javs"))
local _dict = require(game:GetService("ServerStorage"):WaitForChild("dict")) -- "dictionary"

local _Object = _javs.Object
local _Symbol = _javs.Symbol

local _EnumType = _Object("EnumType", function() 
    return {
        init = function(this, name, value)
            this.Name = name
            this.Value = value

            return _Object.freeze(this)
        end
    }
end)

local _enumType_proto = getmetatable(_EnumType.prototype)

_enumType_proto.__tostring = function(this)
    return "<constructor 'EnumType'>"
end

local _isEnumSymbol = _Symbol("isEnum")
local _Enum
_Enum = _Object("Enum", function()
    return {
        init = function(this, enumType, enumData)
            this.EnumType = enumType
            this._enums = {}

            for key, value in pairs(enumData) do
                local newEnum = _EnumType(key, value)
                this[key] = newEnum
                this._enums[key] = newEnum
            end

            _Enum[enumType] = this
        end
    }
end)

function _Enum.isEnum(enum)
    return type(enum) == "table" and enum[_isEnumSymbol] == true
end

function _Enum.get(enumType, name)
    local enum = _Enum[enumType]
    return enum and enum._enums[name]
end

function _Enum.values(enumType)
    local enum = _Enum[enumType]
    local values = {}
    if not enum then return values end

    for _, value in pairs(enum._enums) do
        values[#values + 1] = value
    end

    table.sort(values, function(left, right)
        return left.Name < right.Name
    end)
    return values
end

function _Enum.fromValue(enumType, value)
    for _, enumValue in ipairs(_Enum.values(enumType)) do
        if enumValue.Value == value then return enumValue end
    end
end

local _enum_proto = getmetatable(_Enum.prototype)

_Enum.prototype[_isEnumSymbol] = true

function _Enum.prototype:has(name)
    return self._enums[name] ~= nil
end

function _Enum.prototype:get(name)
    return self._enums[name]
end

function _Enum.prototype:values()
    return _Enum.values(self.EnumType)
end

_enum_proto.__tostring = function(this)
    return "<cnstructor 'Enum'>"
end

return _Enum
