local javs = {}
local prototypua = require(script:WaitForChild("prototypua"))

local function constructor(name, prototype, factory)
	local value = { name = name, prototype = prototype }
	setmetatable(value, { __call = function(_, ...) return factory(...) end })
	prototype.constructor = value
	return value
end

local function instance(prototype, fields)
	fields = fields or {}
	fields.__prototype = prototype
	local metatable = {
		__index = function(value, key)
			local getters = prototype.__getters
			if getters and getters[key] then
				return getters[key](value)
			end
			return prototype[key]
		end
	}
	local prototype_metatable = getmetatable(prototype)
	if prototype_metatable then
		for key, value in pairs(prototype_metatable) do
			if key ~= "__index" then metatable[key] = value end
		end
	end
	for _, metamethod in ipairs({ "__add", "__sub", "__mul", "__div", "__eq", "__lt", "__le" }) do if prototype[metamethod] then metatable[metamethod] = prototype[metamethod] end end
	return setmetatable(fields, metatable)
end

local ObjectPrototype = prototypua.createPrototype()
local Object
Object = constructor("Object", ObjectPrototype, function(value, definition)
	if type(value) == "string" and type(definition) == "function" then
		local prototype = prototypua.createPrototype({ name = value }, ObjectPrototype)
		local members = definition() or {}
		for key, member in pairs(members) do if key ~= "init" then prototype[key] = member end end
		return constructor(value, prototype, function(...)
			local result = instance(prototype)
			if members.init then members.init(result, ...) end
			return result
		end)
	end
	if value == nil then return instance(ObjectPrototype) end
	if type(value) == "table" then return value end
	return instance(ObjectPrototype, { value = value })
end)

function ObjectPrototype:hasOwnProperty(key) return rawget(self, key) ~= nil end
function ObjectPrototype:toString() return "[object " .. (self.__type or "Object") .. "]" end
function ObjectPrototype:valueOf() return self end
function Object.keys(value)
	local result = {}
	if type(value) ~= "table" then return result end
	for key in pairs(value) do if key ~= "__prototype" and type(key) ~= "function" then result[#result + 1] = key end end
	return result
end
function Object.values(value) local result = {}; for _, key in ipairs(Object.keys(value)) do result[#result + 1] = value[key] end; return result end
function Object.entries(value) local result = {}; for _, key in ipairs(Object.keys(value)) do result[#result + 1] = { key, value[key] } end; return result end
function Object.assign(target, ...)
	target = target or instance(ObjectPrototype)
	for i = 1, select("#", ...) do local source = select(i, ...); if type(source) == "table" then for key, value in pairs(source) do target[key] = value end end end
	return target
end
function Object.create(prototype) return instance(prototype or ObjectPrototype) end
Object.getPrototypeOf = function(value) return value and value.__prototype end
Object.is = function(a, b) return a == b end
Object.freeze = function(value) return value end
Object.seal = Object.freeze

local ArrayPrototype = prototypua.createPrototype({}, ObjectPrototype)
local function array(values) return instance(ArrayPrototype, values or {}) end
local Array = constructor("Array", ArrayPrototype, function(...)
	local count = select("#", ...)
	if count == 1 and type((...)) == "number" then return array({ length = (...) }) end
	return array({ ... })
end)
function ArrayPrototype:push(...) for i = 1, select("#", ...) do self[#self + 1] = select(i, ...) end; return #self end
function ArrayPrototype:pop() local value = self[#self]; self[#self] = nil; return value end
function ArrayPrototype:shift() return table.remove(self, 1) end
function ArrayPrototype:unshift(...) for i = select("#", ...), 1, -1 do table.insert(self, 1, select(i, ...)) end; return #self end
function ArrayPrototype:join(separator) return table.concat(self, separator or ",") end
function ArrayPrototype:slice(first, last)
	first = first or 0; if first < 0 then first = #self + first end; last = last or #self; if last < 0 then last = #self + last end
	local result = {}; for i = first + 1, math.min(last, #self) do result[#result + 1] = self[i] end; return array(result)
end
function ArrayPrototype:includes(value) for i = 1, #self do if self[i] == value then return true end end; return false end
function ArrayPrototype:indexOf(value) for i = 1, #self do if self[i] == value then return i - 1 end end; return -1 end
function ArrayPrototype:forEach(callback) for i = 1, #self do callback(self[i], i - 1, self) end end
function ArrayPrototype:map(callback) local result = {}; for i = 1, #self do result[i] = callback(self[i], i - 1, self) end; return array(result) end
function ArrayPrototype:filter(callback) local result = {}; for i = 1, #self do if callback(self[i], i - 1, self) then result[#result + 1] = self[i] end end; return array(result) end
function ArrayPrototype:find(callback) for i = 1, #self do if callback(self[i], i - 1, self) then return self[i] end end end
function ArrayPrototype:findIndex(callback) for i = 1, #self do if callback(self[i], i - 1, self) then return i - 1 end end; return -1 end
function ArrayPrototype:some(callback) for i = 1, #self do if callback(self[i], i - 1, self) then return true end end; return false end
function ArrayPrototype:every(callback) for i = 1, #self do if not callback(self[i], i - 1, self) then return false end end; return true end
function ArrayPrototype:concat(...) local result = {}; for i = 1, #self do result[#result + 1] = self[i] end; for i = 1, select("#", ...) do local value = select(i, ...); if type(value) == "table" and Array.isArray(value) then for _, item in ipairs(value) do result[#result + 1] = item end else result[#result + 1] = value end end; return array(result) end
function ArrayPrototype:at(index) if index < 0 then index = #self + index end; return self[index + 1] end
function ArrayPrototype:flat(depth) depth = depth or 1; local result = {}; local function flatten(value, level) if level > 0 and type(value) == "table" and Array.isArray(value) then for _, item in ipairs(value) do flatten(item, level - 1) end else result[#result + 1] = value end end; for _, item in ipairs(self) do flatten(item, depth) end; return array(result) end
function ArrayPrototype:flatMap(callback) return self:map(callback):flat(1) end
function ArrayPrototype:sort(compare) table.sort(self, function(a, b) if compare then return compare(a, b) < 0 end; return tostring(a) < tostring(b) end); return self end
function ArrayPrototype:reduce(callback, initial)
	local index, result = 1, initial; if result == nil then result, index = self[1], 2 end
	for i = index, #self do result = callback(result, self[i], i - 1, self) end; return result
end
function ArrayPrototype:reverse() local result = {}; for i = #self, 1, -1 do result[#result + 1] = self[i] end; return array(result) end
Array.isArray = function(value) return type(value) == "table" and value.__prototype == ArrayPrototype end
Array.from = function(value) local result = {}; for i, item in ipairs(value or {}) do result[i] = item end; return array(result) end
Array.of = function(...) return array({ ... }) end

local StringPrototype = prototypua.createPrototype({}, ObjectPrototype)
local String = constructor("String", StringPrototype, function(value) return tostring(value == nil and "" or value) end)
function StringPrototype:toString() return self end
function StringPrototype:valueOf() return self end
function StringPrototype:includes(value) return self:find(tostring(value), 1, true) ~= nil end
function StringPrototype:startsWith(value) return self:sub(1, #value) == value end
function StringPrototype:endsWith(value) return value == "" or self:sub(-#value) == value end
function StringPrototype:trim() return self:match("^%s*(.-)%s*$") end
function StringPrototype:toUpperCase() return self:upper() end
function StringPrototype:toLowerCase() return self:lower() end
function StringPrototype:charAt(index) return self:sub(index + 1, index + 1) end
function StringPrototype:split(separator)
	local result = {}
	if not separator or separator == "" then for i = 1, #self do result[i] = self:sub(i, i) end
	else for item in (self .. separator):gmatch("(.-)" .. separator) do result[#result + 1] = item end end
	return array(result)
end
String.fromCharCode = function(...) local result = {}; for i = 1, select("#", ...) do result[i] = string.char(select(i, ...)) end; return table.concat(result) end
String.fromCodePoint = String.fromCharCode
String.raw = function(value, ...) local result = value.raw or {}; local output = {}; for i, item in ipairs(result) do output[#output + 1] = item; if i <= select("#", ...) then output[#output + 1] = tostring(select(i, ...)) end end; return table.concat(output) end

local NumberPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Number = constructor("Number", NumberPrototype, function(value) return tonumber(value) or 0 end)
Number.isNaN = function(value) return type(value) == "number" and value ~= value end
Number.isFinite = function(value) return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge end
Number.isInteger = function(value) return Number.isFinite(value) and value % 1 == 0 end
function NumberPrototype:toString() return tostring(self) end
function NumberPrototype:valueOf() return self end

local BooleanPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Boolean = constructor("Boolean", BooleanPrototype, function(value) return not (value == nil or value == false or value == 0 or value == "") end)

local SymbolPrototype = prototypua.createPrototype({}, ObjectPrototype)
local symbol_id, symbol_registry = 0, {}
local Symbol = constructor("Symbol", SymbolPrototype, function(description)
	symbol_id = symbol_id + 1
	return instance(SymbolPrototype, { description = description, id = symbol_id })
end)
function SymbolPrototype:toString() return "Symbol(" .. tostring(self.description or "") .. ")" end
Symbol["for"] = function(key) symbol_registry[key] = symbol_registry[key] or Symbol(key); return symbol_registry[key] end
Symbol.keyFor = function(value) for key, symbol in pairs(symbol_registry) do if symbol == value then return key end end end

local MapPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Map = constructor("Map", MapPrototype, function(entries)
	local result = instance(MapPrototype, { _entries = {} }); for _, pair in ipairs(entries or {}) do result:set(pair[1], pair[2]) end; return result
end)
function MapPrototype:set(key, value) for _, pair in ipairs(self._entries) do if pair[1] == key then pair[2] = value; return self end end; self._entries[#self._entries + 1] = { key, value }; return self end
function MapPrototype:get(key) for _, pair in ipairs(self._entries) do if pair[1] == key then return pair[2] end end end
function MapPrototype:has(key) return self:get(key) ~= nil end
function MapPrototype:delete(key) for i, pair in ipairs(self._entries) do if pair[1] == key then table.remove(self._entries, i); return true end end; return false end
function MapPrototype:clear() self._entries = {} end
function MapPrototype:forEach(callback) for _, pair in ipairs(self._entries) do callback(pair[2], pair[1], self) end end
function MapPrototype:keys() local result = {}; for _, pair in ipairs(self._entries) do result[#result + 1] = pair[1] end; return array(result) end
function MapPrototype:values() local result = {}; for _, pair in ipairs(self._entries) do result[#result + 1] = pair[2] end; return array(result) end
function MapPrototype:entries() return array(self._entries) end
function MapPrototype:size() return #self._entries end

local SetPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Set = constructor("Set", SetPrototype, function(values) local result = instance(SetPrototype, { _values = {} }); for _, value in ipairs(values or {}) do result:add(value) end; return result end)
function SetPrototype:add(value) if not self:has(value) then self._values[#self._values + 1] = value end; return self end
function SetPrototype:has(value) for _, item in ipairs(self._values) do if item == value then return true end end; return false end
function SetPrototype:delete(value) for i, item in ipairs(self._values) do if item == value then table.remove(self._values, i); return true end end; return false end
function SetPrototype:values() return array(self._values) end
SetPrototype.keys = SetPrototype.values
function SetPrototype:size() return #self._values end
function SetPrototype:clear() self._values = {} end
function SetPrototype:union(other) local result = Set(self._values); for _, value in ipairs(other and other._values or {}) do result:add(value) end; return result end
function SetPrototype:intersection(other) local result = Set(); for _, value in ipairs(self._values) do if other and other:has(value) then result:add(value) end end; return result end
function SetPrototype:difference(other) local result = Set(); for _, value in ipairs(self._values) do if not other or not other:has(value) then result:add(value) end end; return result end

local HeadersPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Headers = constructor("Headers", HeadersPrototype, function(init)
	local result = instance(HeadersPrototype, { _values = {} })
	if type(init) == "table" then for key, value in pairs(init) do result:set(key, value) end end
	return result
end)
function HeadersPrototype:set(key, value) self._values[tostring(key):lower()] = tostring(value) end
function HeadersPrototype:append(key, value) local name = tostring(key):lower(); self._values[name] = self._values[name] and self._values[name] .. ", " .. tostring(value) or tostring(value) end
function HeadersPrototype:get(key) return self._values[tostring(key):lower()] end
function HeadersPrototype:has(key) return self:get(key) ~= nil end
function HeadersPrototype:delete(key) self._values[tostring(key):lower()] = nil end
function HeadersPrototype:entries() local result = {}; for key, value in pairs(self._values) do result[#result + 1] = { key, value } end; return array(result) end

local function weak_constructor(name, is_set)
	local prototype = prototypua.createPrototype({}, ObjectPrototype)
	local result = constructor(name, prototype, function(entries) local value = instance(prototype, { _entries = {} }); for _, pair in ipairs(entries or {}) do value:set(pair[1], is_set and true or pair[2]) end; return value end)
	function prototype:set(key, value) self._entries[key] = is_set and true or value; return self end
	function prototype:get(key) return self._entries[key] end
	function prototype:has(key) return self._entries[key] ~= nil end
	function prototype:delete(key) local found = self:has(key); self._entries[key] = nil; return found end
	return result
end
local WeakMap, WeakSet = weak_constructor("WeakMap", false), weak_constructor("WeakSet", true)

local DatePrototype = prototypua.createPrototype({}, ObjectPrototype)
local Date = constructor("Date", DatePrototype, function(value) return instance(DatePrototype, { timestamp = value or os.time() }) end)
function DatePrototype:getTime() return self.timestamp * 1000 end
function DatePrototype:toISOString() return os.date("!%Y-%m-%dT%H:%M:%SZ", self.timestamp) end
function DatePrototype:toString() return os.date("%c", self.timestamp) end
Date.now = function() return os.time() * 1000 end
Date.parse = function(value) local timestamp = os.time({ year = tonumber(tostring(value):sub(1, 4)), month = tonumber(tostring(value):sub(6, 7)), day = tonumber(tostring(value):sub(9, 10)), hour = 0, min = 0, sec = 0 }); return timestamp * 1000 end
Date.UTC = Date.parse

local RegExpPrototype = prototypua.createPrototype({}, ObjectPrototype)
local RegExp = constructor("RegExp", RegExpPrototype, function(pattern, flags) return instance(RegExpPrototype, { source = pattern or "", flags = flags or "" }) end)
function RegExpPrototype:test(value) return string.find(value, self.source, 1, true) ~= nil end
function RegExpPrototype:exec(value) local first, last = string.find(value, self.source, 1, true); if not first then return nil end; return array({ value:sub(first, last) }) end

local ErrorPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Error = constructor("Error", ErrorPrototype, function(message) return instance(ErrorPrototype, { name = "Error", message = tostring(message or "") }) end)
function ErrorPrototype:toString() return self.name .. ": " .. self.message end
local function error_constructor(name)
	local prototype = prototypua.createPrototype({}, ErrorPrototype)
	local value = constructor(name, prototype, function(message) return instance(prototype, { name = name, message = tostring(message or "") }) end)
	return value
end
local TypeError, RangeError, ReferenceError, SyntaxError = error_constructor("TypeError"), error_constructor("RangeError"), error_constructor("ReferenceError"), error_constructor("SyntaxError")
local EvalError, URIError, AggregateError = error_constructor("EvalError"), error_constructor("URIError"), error_constructor("AggregateError")

local function json_quote(value) return string.format("%q", value) end
local function json_encode(value, seen)
	if value == nil then return "null" end
	if type(value) == "string" then return json_quote(value) end
	if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
	if type(value) ~= "table" then return "null" end
	seen = seen or {}; if seen[value] then error("Converting circular structure to JSON") end; seen[value] = true
	local parts, is_array = {}, Array and Array.isArray(value) or #value > 0
	if is_array then for i = 1, #value do parts[#parts + 1] = json_encode(value[i], seen) end; seen[value] = nil; return "[" .. table.concat(parts, ",") .. "]" end
	for key, item in pairs(value) do if type(key) == "string" and key ~= "__prototype" then parts[#parts + 1] = json_quote(key) .. ":" .. json_encode(item, seen) end end
	seen[value] = nil; return "{" .. table.concat(parts, ",") .. "}"
end
local function json_parser(text)
	local position = 1
	local function spaces() while text:sub(position, position):match("%s") do position = position + 1 end end
	local parse
	local function string_value()
		position = position + 1; local result = {}
		while text:sub(position, position) ~= '"' do
			if text:sub(position, position) == "\\" then position = position + 1; local escapes = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }; result[#result + 1] = escapes[text:sub(position, position)] or text:sub(position, position)
			else result[#result + 1] = text:sub(position, position) end
			position = position + 1
		end
		position = position + 1; return table.concat(result)
	end
	parse = function()
		spaces(); local character = text:sub(position, position)
		if character == '"' then return string_value() end
		if character == "{" then position = position + 1; local result = {}; spaces(); while text:sub(position, position) ~= "}" do local key = string_value(); spaces(); position = position + 1; result[key] = parse(); spaces(); if text:sub(position, position) == "," then position = position + 1; spaces() end end; position = position + 1; return result end
		if character == "[" then position = position + 1; local result = {}; spaces(); while text:sub(position, position) ~= "]" do result[#result + 1] = parse(); spaces(); if text:sub(position, position) == "," then position = position + 1; spaces() end end; position = position + 1; return array(result) end
		if text:sub(position, position + 3) == "true" then position = position + 4; return true end
		if text:sub(position, position + 4) == "false" then position = position + 5; return false end
		if text:sub(position, position + 3) == "null" then position = position + 4; return nil end
		local number = text:match("%-?%d+%.?%d*[eE]?[-+]?%d*", position); if not number then error("Invalid JSON at position " .. position) end; position = position + #number; return tonumber(number)
	end
	local result = parse(); spaces(); if position <= #text then error("Unexpected JSON content at position " .. position) end; return result
end
local JSON = { stringify = json_encode, parse = json_parser }

local BigIntPrototype = prototypua.createPrototype({}, ObjectPrototype)
local BigInt = constructor("BigInt", BigIntPrototype, function(value) return instance(BigIntPrototype, { value = tostring(value or 0) }) end)
function BigIntPrototype:toString() return self.value end
function BigIntPrototype:valueOf() return self.value end
local function bigint_number(value) return tonumber(value.value or value) end
BigIntPrototype.__add = function(a, b) return BigInt(bigint_number(a) + bigint_number(b)) end
BigIntPrototype.__sub = function(a, b) return BigInt(bigint_number(a) - bigint_number(b)) end
BigIntPrototype.__mul = function(a, b) return BigInt(bigint_number(a) * bigint_number(b)) end

local Reflect = {}
Reflect.get = function(target, key) return target[key] end
Reflect.set = function(target, key, value) target[key] = value; return true end
Reflect.has = function(target, key) return target[key] ~= nil end
Reflect.deleteProperty = function(target, key) target[key] = nil; return true end
Reflect.ownKeys = Object.keys
local Proxy = constructor("Proxy", ObjectPrototype, function(target, handlers)
	local proxy = {}
	return setmetatable(proxy, { __index = function(_, key) return handlers.get and handlers.get(target, key) or target[key] end, __newindex = function(_, key, value) if handlers.set then handlers.set(target, key, value) else target[key] = value end end, __pairs = function() return pairs(target) end })
end)

local function typed_array(name, converter)
	local prototype = prototypua.createPrototype({}, ArrayPrototype)
	local value = constructor(name, prototype, function(source)
		local result = instance(prototype, {})
		if type(source) == "number" then for i = 1, source do result[i] = 0 end else for i, item in ipairs(source or {}) do result[i] = converter(item) end end
		return result
	end)
	function prototype:at(index) return self[index + 1] end
	function prototype:set(source, offset) for i, item in ipairs(source) do self[(offset or 0) + i] = converter(item) end end
	prototype.BYTES_PER_ELEMENT = 1
	return value
end
local ArrayBufferPrototype = prototypua.createPrototype({}, ObjectPrototype)
local ArrayBuffer = constructor("ArrayBuffer", ArrayBufferPrototype, function(length) local result = instance(ArrayBufferPrototype, { bytes = {} }); for i = 1, length or 0 do result.bytes[i] = 0 end; return result end)
function ArrayBufferPrototype:byteLength() return #self.bytes end
local Uint8Array = typed_array("Uint8Array", function(value) return math.floor(tonumber(value) or 0) % 256 end)
local Int32Array = typed_array("Int32Array", function(value) return math.floor(tonumber(value) or 0) end)
local Int8Array = typed_array("Int8Array", function(value) local number = math.floor(tonumber(value) or 0) % 256; return number > 127 and number - 256 or number end)
local Uint8ClampedArray = typed_array("Uint8ClampedArray", function(value) return math.max(0, math.min(255, math.floor((tonumber(value) or 0) + 0.5))) end)
local Uint16Array = typed_array("Uint16Array", function(value) return math.floor(tonumber(value) or 0) % 65536 end)
local Int16Array = typed_array("Int16Array", function(value) local number = math.floor(tonumber(value) or 0) % 65536; return number > 32767 and number - 65536 or number end)
local Uint32Array = typed_array("Uint32Array", function(value) return math.floor(tonumber(value) or 0) % 4294967296 end)
local Float32Array = typed_array("Float32Array", function(value) return tonumber(value) or 0 end)
local Float64Array = typed_array("Float64Array", function(value) return tonumber(value) or 0 end)
local DataViewPrototype = prototypua.createPrototype({}, ObjectPrototype)
local DataView = constructor("DataView", DataViewPrototype, function(buffer) return instance(DataViewPrototype, { buffer = buffer, offset = 0 }) end)
function DataViewPrototype:getUint8(index) return self.buffer.bytes[self.offset + index + 1] or 0 end
function DataViewPrototype:setUint8(index, value) self.buffer.bytes[self.offset + index + 1] = math.floor(value) % 256 end

local WeakRefPrototype = prototypua.createPrototype({}, ObjectPrototype)
local WeakRef = constructor("WeakRef", WeakRefPrototype, function(value) return instance(WeakRefPrototype, { target = value }) end)
function WeakRefPrototype:deref() return self.target end

local FunctionPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Function = constructor("Function", FunctionPrototype, function(callback) if type(callback) ~= "function" then error("Function requires a Lua function callback") end; return instance(FunctionPrototype, { callback = callback }) end)
function FunctionPrototype:call(this_value, ...) return self.callback(this_value, ...) end
function FunctionPrototype:apply(this_value, arguments) return self.callback(this_value, table.unpack(arguments or {})) end
function FunctionPrototype:bind(this_value, ...)
	local bound = { callback = self.callback, this_value = this_value, arguments = { ... } }
	return setmetatable(bound, { __index = FunctionPrototype, __call = function(value, ...) local arguments = {}; for _, item in ipairs(value.arguments) do arguments[#arguments + 1] = item end; for i = 1, select("#", ...) do arguments[#arguments + 1] = select(i, ...) end; return value.callback(value.this_value, table.unpack(arguments)) end })
end

local function clone(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}; if seen[value] then return seen[value] end
	local result = {}; seen[value] = result
	for key, item in pairs(value) do if key ~= "__prototype" then result[clone(key, seen)] = clone(item, seen) end end
	return setmetatable(result, getmetatable(value))
end
local Console = {}
function Console.log(...) local values = {}; for i = 1, select("#", ...) do values[i] = tostring(select(i, ...)) end; print(table.concat(values, "\t")) end
Console.info, Console.warn, Console.error = Console.log, Console.log, Console.log
local function uri_escape(value) return tostring(value):gsub("[^%w%-%._~]", function(character) return string.format("%%%02X", string.byte(character)) end) end
local function uri_unescape(value) return tostring(value):gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end) end

local PromisePrototype = prototypua.createPrototype({}, ObjectPrototype)
local Promise = constructor("Promise", PromisePrototype, function(executor)
	local result = instance(PromisePrototype, { state = "pending", value = nil, reason = nil })
	local function resolve(value) if result.state == "pending" then result.state, result.value = "fulfilled", value end end
	local function reject(reason) if result.state == "pending" then result.state, result.reason = "rejected", reason end end
	if type(executor) ~= "function" then error("Promise resolver is not a function") end
	local ok, reason = pcall(executor, resolve, reject); if not ok then reject(reason) end
	return result
end)
function PromisePrototype:then_(on_fulfilled, on_rejected)
	if self.state == "fulfilled" then return Promise.resolve(on_fulfilled and on_fulfilled(self.value) or self.value) end
	if self.state == "rejected" then if on_rejected then return Promise.resolve(on_rejected(self.reason)) end; return Promise.reject(self.reason) end
end
function PromisePrototype:catch(on_rejected) return self:then_(nil, on_rejected) end
function PromisePrototype:finally_(callback) if self.state == "fulfilled" then callback(); return Promise.resolve(self.value) end; callback(); return Promise.reject(self.reason) end
Promise.resolve = function(value) if type(value) == "table" and value.__prototype == PromisePrototype then return value end; return Promise(function(resolve) resolve(value) end) end
Promise.reject = function(reason) return Promise(function(_, reject) reject(reason) end) end
Promise.all = function(values)
	local result = {}; for i, value in ipairs(values or {}) do local promise = Promise.resolve(value); if promise.state == "rejected" then return Promise.reject(promise.reason) end; result[i] = promise.value end
	return Promise.resolve(array(result))
end
Promise.race = function(values) for _, value in ipairs(values or {}) do return Promise.resolve(value) end; return Promise(function() end) end

local EventPrototype = prototypua.createPrototype({}, ObjectPrototype)
local Event = constructor("Event", EventPrototype, function(event_type, options)
	options = options or {}
	return instance(EventPrototype, { type = tostring(event_type), bubbles = options.bubbles == true, cancelable = options.cancelable == true, defaultPrevented = false, target = nil, currentTarget = nil, _stopped = false })
end)
function EventPrototype:preventDefault() if self.cancelable then self.defaultPrevented = true end end
function EventPrototype:stopPropagation() self._stopped = true end
function EventPrototype:stopImmediatePropagation() self._stopped = true; self._immediate = true end

local CustomEventPrototype = prototypua.createPrototype({}, EventPrototype)
local CustomEvent = constructor("CustomEvent", CustomEventPrototype, function(event_type, options)
	options = options or {}
	local result = instance(CustomEventPrototype, { type = tostring(event_type), bubbles = options.bubbles == true, cancelable = options.cancelable == true, detail = options.detail, defaultPrevented = false, target = nil, currentTarget = nil, _stopped = false })
	return result
end)

local EventTargetPrototype = prototypua.createPrototype({}, ObjectPrototype)
local EventTarget = constructor("EventTarget", EventTargetPrototype, function() return instance(EventTargetPrototype, { _listeners = {} }) end)
function EventTargetPrototype:addEventListener(event_type, callback, options)
	if type(callback) ~= "function" and not (type(callback) == "table" and type(callback.handleEvent) == "function") then return end
	local listeners = self._listeners[event_type] or {}; self._listeners[event_type] = listeners
	for _, listener in ipairs(listeners) do if listener.callback == callback then return end end
	listeners[#listeners + 1] = { callback = callback, once = type(options) == "table" and options.once == true }
end
function EventTargetPrototype:removeEventListener(event_type, callback)
	local listeners = self._listeners[event_type] or {}
	for i = #listeners, 1, -1 do if listeners[i].callback == callback then table.remove(listeners, i) end end
end
function EventTargetPrototype:dispatchEvent(event)
	if type(event) ~= "table" or not event.type then error("dispatchEvent requires an Event") end
	event.target, event.currentTarget = event.target or self, self
	local listeners = self._listeners[event.type] or {}
	for i = 1, #listeners do
		local listener = listeners[i]
		if type(listener.callback) == "function" then listener.callback(event) else listener.callback:handleEvent(event) end
		if listener.once then self:removeEventListener(event.type, listener.callback) end
		if event._immediate then break end
	end
	return not event.defaultPrevented
end

local URLSearchParamsPrototype = prototypua.createPrototype({}, ObjectPrototype)
local URLSearchParams = constructor("URLSearchParams", URLSearchParamsPrototype, function(init)
	local result = instance(URLSearchParamsPrototype, { _pairs = {} })
	if type(init) == "string" then
		for pair in (init:gsub("^?", "") .. "&"):gmatch("([^&]*)&") do
			local key, value = pair:match("^([^=]*)=(.*)$")
			if key then result:append(uri_unescape(key), uri_unescape(value)) elseif pair ~= "" then result:append(uri_unescape(pair), "") end
		end
	elseif type(init) == "table" then
		for key, value in pairs(init) do result:append(key, value) end
	end
	return result
end)
function URLSearchParamsPrototype:append(key, value) self._pairs[#self._pairs + 1] = { tostring(key), tostring(value) } end
function URLSearchParamsPrototype:get(key) for _, pair in ipairs(self._pairs) do if pair[1] == tostring(key) then return pair[2] end end end
function URLSearchParamsPrototype:has(key) return self:get(key) ~= nil end
function URLSearchParamsPrototype:set(key, value) for _, pair in ipairs(self._pairs) do if pair[1] == tostring(key) then pair[2] = tostring(value); return end end; self:append(key, value) end
function URLSearchParamsPrototype:delete(key) for i = #self._pairs, 1, -1 do if self._pairs[i][1] == tostring(key) then table.remove(self._pairs, i) end end end
function URLSearchParamsPrototype:toString() local result = {}; for _, pair in ipairs(self._pairs) do result[#result + 1] = uri_escape(pair[1]) .. "=" .. uri_escape(pair[2]) end; return table.concat(result, "&") end

local URLPrototype = prototypua.createPrototype({}, ObjectPrototype)
local URL = constructor("URL", URLPrototype, function(input, base)
	local value = tostring(input or "")
	if not value:match("^[%w+.-]+://") and base then
		local base_value = tostring(base)
		if value:sub(1, 1) == "/" then value = base_value:match("^[%w+.-]+://[^/]+") .. value
		else value = base_value:gsub("/[^/]*$", "") .. "/" .. value end
	end
	local protocol, remainder = value:match("^([%w+.-]+://)(.*)$")
	if not protocol then error("Invalid URL") end
	local authority, path = remainder:match("^([^/?#]*)(.*)$")
	local host, port = authority:match("^([^:]+):(%d+)$")
	host, port = host or authority, port or ""
	local without_fragment, fragment = path:match("^([^#]*)#?(.*)$")
	local pathname, query = without_fragment:match("^([^?]*)%??(.*)$")
	local result = instance(URLPrototype, { protocol = protocol, host = authority, hostname = host, port = port, pathname = pathname ~= "" and pathname or "/", search = query ~= "" and "?" .. query or "", hash = fragment ~= "" and "#" .. fragment or "" })
	result.searchParams = URLSearchParams(query)
	result.href = value
	return result
end)
function URLPrototype:toString() return self.href end
function URLPrototype:toJSON() return self.href end

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function fetch_request(url, options)
	options = options or {}
	local header_path, body_path = os.tmpname(), os.tmpname()
	local command = "curl --silent --show-error --location --max-time " .. tostring(options.timeout or 30) .. " --request " .. shell_quote(string.upper(options.method or "GET"))
	if options.body ~= nil then command = command .. " --data-binary " .. shell_quote(type(options.body) == "table" and JSON.stringify(options.body) or options.body) end
	local request_headers = options.headers and options.headers._values or options.headers or {}
	for key, value in pairs(request_headers) do command = command .. " --header " .. shell_quote(key .. ": " .. value) end
	command = command .. " --dump-header " .. shell_quote(header_path) .. " --output " .. shell_quote(body_path) .. " " .. shell_quote(url) .. " 2>/dev/null"
	local process = io.popen(command)
	local succeeded = process and process:close()
	local body_file = io.open(body_path, "rb")
	local header_file = io.open(header_path, "r")
	local body = body_file and body_file:read("*a") or ""
	local raw_headers = header_file and header_file:read("*a") or ""
	if body_file then body_file:close() end
	if header_file then header_file:close() end
	os.remove(body_path); os.remove(header_path)
	if not succeeded and raw_headers == "" then return nil, "fetch failed" end
	local status = tonumber(raw_headers:match("HTTP/%d%.%d%s+(%d+)[^\r\n]*$")) or tonumber(raw_headers:match("HTTP/%d%.%d%s+(%d+)")) or 0
	local headers = {}
	for key, value in raw_headers:gmatch("\r?\n([^:\r\n]+):%s*([^\r\n]*)") do headers[key:lower()] = value end
	local response = { status = status, ok = status >= 200 and status < 300, headers = headers, body = body, url = url }
	function response:text() return Promise.resolve(self.body) end
	function response:json() return Promise.resolve(JSON.parse(self.body)) end
	function response:arrayBuffer() local buffer = ArrayBuffer(#self.body); for i = 1, #self.body do buffer.bytes[i] = string.byte(self.body, i) end; return Promise.resolve(buffer) end
	function response:clone() return fetch_response(self) end
	return response
end

function fetch_response(response)
	return { status = response.status, ok = response.ok, headers = response.headers, body = response.body, url = response.url, text = response.text, json = response.json, arrayBuffer = response.arrayBuffer }
end

local function fetch(url, options)
	local target = type(url) == "table" and url.href or tostring(url)
	local response, reason = fetch_request(target, options)
	if not response then return Promise.reject(reason) end
	return Promise.resolve(response)
end

javs.Object, javs.Array, javs.String, javs.Number = Object, Array, String, Number
javs.Boolean, javs.Symbol, javs.Map, javs.Set = Boolean, Symbol, Map, Set
javs.Headers = Headers
javs.Event, javs.CustomEvent, javs.EventTarget = Event, CustomEvent, EventTarget
javs.prototypua = prototypua
javs.WeakMap, javs.WeakSet = WeakMap, WeakSet
javs.Date, javs.RegExp, javs.Error = Date, RegExp, Error
javs.TypeError, javs.RangeError = TypeError, RangeError
javs.ReferenceError, javs.SyntaxError = ReferenceError, SyntaxError
javs.EvalError, javs.URIError, javs.AggregateError = EvalError, URIError, AggregateError
javs.Promise = Promise
javs.JSON, javs.BigInt, javs.Reflect, javs.Proxy = JSON, BigInt, Reflect, Proxy
javs.ArrayBuffer, javs.DataView = ArrayBuffer, DataView
javs.Int8Array, javs.Uint8Array, javs.Uint8ClampedArray = Int8Array, Uint8Array, Uint8ClampedArray
javs.Int16Array, javs.Uint16Array, javs.Int32Array = Int16Array, Uint16Array, Int32Array
javs.Uint32Array, javs.Float32Array, javs.Float64Array = Uint32Array, Float32Array, Float64Array
javs.WeakRef = WeakRef
javs.Function, javs.console = Function, Console
javs.structuredClone = clone
javs.fetch, javs.URL, javs.URLSearchParams = fetch, URL, URLSearchParams
javs.encodeURI, javs.encodeURIComponent = uri_escape, uri_escape
javs.decodeURI, javs.decodeURIComponent = uri_unescape, uri_unescape
javs.NaN, javs.Infinity = 0 / 0, math.huge
javs.typeof = function(value) if value == nil then return "undefined" end; if type(value) == "table" and value.__prototype then return value.__prototype.name or (value.__prototype.constructor and value.__prototype.constructor.name) or "object" end; return type(value) end
javs.Math = setmetatable({ PI = math.pi, random = math.random, round = function(value) return math.floor(value + 0.5) end, trunc = function(value) return value < 0 and math.ceil(value) or math.floor(value) end }, { __index = math })
javs.Math.E = math.exp(1)
javs.Math.LN2, javs.Math.LN10 = math.log(2), math.log(10)
javs.Math.LOG2E, javs.Math.LOG10E = 1 / math.log(2), 1 / math.log(10)
javs.Math.SQRT1_2, javs.Math.SQRT2 = math.sqrt(0.5), math.sqrt(2)
javs.Math.abs = math.abs
javs.Math.sign = function(value) return value < 0 and -1 or (value > 0 and 1 or value) end
javs.Math.cbrt = function(value) return value < 0 and -((-value) ^ (1 / 3)) or value ^ (1 / 3) end
javs.Math.hypot = function(...) local sum = 0; for i = 1, select("#", ...) do local value = select(i, ...); sum = sum + value * value end; return math.sqrt(sum) end
javs.Math.clz32 = function(value) local number = math.floor(tonumber(value) or 0) % 4294967296; if number == 0 then return 32 end; local count = 0; while number < 2147483648 do number = number * 2; count = count + 1 end; return count end
javs.Math.imul = function(a, b) return (math.floor(a) * math.floor(b)) % 4294967296 end
javs.parseInt = function(value, radix) return tonumber(tostring(value):match("^[%s]*([+-]?%d+)"), radix or 10) end
javs.parseFloat = function(value) return tonumber(tostring(value):match("^[%s]*([+-]?%d+%.?%d*)")) end
javs.isNaN, javs.isFinite = Number.isNaN, Number.isFinite
javs.setTimeout = function(callback) if type(callback) == "function" then callback() end; return 1 end
javs.clearTimeout = function() end
javs.setInterval = javs.setTimeout
javs.clearInterval = javs.clearTimeout
javs.queueMicrotask = function(callback) if type(callback) == "function" then callback() end end

_G.js = _G.js or javs
return javs
