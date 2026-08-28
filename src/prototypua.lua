local prototypua = {}

local function instance(prototype, fields)
	fields = fields or {}
	fields.__proto__ = prototype
	fields.__prototype = prototype
	return setmetatable(fields, { __index = prototype })
end

local function copy_members(target, source)
	for key, value in pairs(source or {}) do
		if key ~= "__proto__" and key ~= "__prototype" then target[key] = value end
	end
	return target
end

function prototypua.constructor(name, initializer, parent)
	local prototype = setmetatable({ name = name }, { __index = parent })
	local constructor = { name = name, prototype = prototype }
	prototype.constructor = constructor
	setmetatable(constructor, {
		__call = function(_, ...)
			local value = instance(prototype)
			if initializer then initializer(value, ...) end
			return value
		end,
		__tostring = function() return "<constructor '" .. name .. "'>" end
	})
	return constructor
end

function prototypua.createPrototype(definition, parent)
	local prototype = setmetatable({}, { __index = parent })
	return copy_members(prototype, definition)
end

function prototypua.chainPrototypes(base, ...)
	local prototype = setmetatable({}, { __index = base })
	for i = 1, select("#", ...) do copy_members(prototype, select(i, ...)) end
	return prototype
end

function prototypua.instance(prototype, fields)
	return instance(prototype, fields)
end

function prototypua.clone(original)
	if type(original) ~= "table" then return original end
	return instance(original.__proto__ or original.__prototype, copy_members({}, original))
end

function prototypua.get(value, key)
	return value and value[key]
end

function prototypua.set(value, key, item)
	value[key] = item
	return value
end

function prototypua.hasOwn(value, key)
	return type(value) == "table" and rawget(value, key) ~= nil
end

function prototypua.getPrototypeOf(value)
	return value and (value.__proto__ or value.__prototype)
end

function prototypua.setPrototypeOf(value, prototype)
	if type(value) ~= "table" then error("setPrototypeOf requires a table") end
	value.__proto__, value.__prototype = prototype, prototype
	setmetatable(value, { __index = prototype })
	return value
end

function prototypua.Class(name, definition, parent)
	definition = definition or {}
	local initializer = definition.init
	local constructor = prototypua.constructor(name, initializer, parent)
	copy_members(constructor.prototype, definition)
	return constructor
end

return prototypua
