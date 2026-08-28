local _javs = require("game:GetService("ServerStorage"):WaitForChild("javs"))
local _Object = _javs.Object
local _Symbol = _javs.Symbol

local _tbl = require(game:GetService("ServerStorage"):WaitForChild("tbl"))

local _isDictionarySymbol = _Symbol("IsDict")
local dict = _Object("Dictionary", function()
	return {
		init = function(this, initial)
			if type(initial) ~= "table" then return this end
			for key, value in pairs(initial) do
				if key ~= "__prototype" then this[key] = value end
			end
			return this
		end
	}
end)

dict.prototype[_isDictionarySymbol] = true

-- Generic contracts for Luau users:
--[=[
type Pair<K, V> = (K, V)
type Predicate<K, V> = (K, V) -> boolean
type ValuePredicate<V> = (V) -> boolean
type KeyFunction<K, T> = (K) -> T
type ValueFunction<V, T> = (V) -> T
type Factory<V> = () -> V
]=]

local function is_mapping(value)
	return type(value) == "table"
end

local function copy_table(value, deep, seen)
	if not is_mapping(value) then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do
		if key ~= "__prototype" then
			result[key] = deep and copy_table(child, true, seen) or child
		end
	end
	return result
end

---Creates a shallow copy of a dictionary-like table without wrapper metadata.
---@param value table The dictionary to clone.
---@return table A plain Lua table copy of the input.
function dict.copy_dict(value)
	assert(is_mapping(value), "Input must be a table.")
	return _tbl.toNative(_tbl.clone(value))
end

---Recursively duplicates a nested table structure while returning plain Lua tables.
---@param value table The nested dictionary to duplicate.
---@return table A deep copy of the input table.
function dict.deep_copy(value)
	assert(is_mapping(value), "Input must be a table.")
	return _tbl.toNative(_tbl.deepClone(value))
end

---Builds a lightweight class-like table with a constructor that initializes new instances.
---@param class_name string The class name to assign to the generated type.
---@param initial table|nil Optional initial attributes to apply to the class.
---@return table The generated class table.
function dict.class(class_name, initial)
	assert(type(class_name) == "string" and class_name:match("^[%a_][%w_]*$"), "Invalid class name.")
	local attributes = dict(initial)
	local base = attributes.__base
	local class = { __name = class_name, __base = base }
	for key, value in pairs(attributes) do
		if key ~= "__base" then class[key] = value end
	end

	local class_meta = {
		__index = base,
		__call = function(class_table, ...)
			local instance = setmetatable({}, { __index = class_table })
			local initializer = class_table.__init or class_table.init
			if initializer then initializer(instance, ...) end
			return instance
		end,
	}
	return setmetatable(class, class_meta)
end

---Combines multiple tables into one, with later entries overriding earlier keys.
---@param ... table One or more tables to merge.
---@return table A merged dictionary.
function dict.merge(...)
	local result = {}
	for _, value in ipairs({ ... }) do
		assert(is_mapping(value), "All arguments must be tables.")
		for key, child in pairs(value) do result[key] = child end
	end
	return result
end

---Merges tables using a custom resolver to decide what value wins for duplicate keys.
---@param ... any A list of dictionaries followed by a resolver function.
---@return table A merged dictionary using the custom resolution strategy.
function dict.merge_with(...)
	local arguments = { ... }
	local resolver = _tbl.remove(arguments)
	assert(type(resolver) == "function", "The last argument must be a resolver function.")
	local result = {}
	for _, value in ipairs(arguments) do
		assert(is_mapping(value), "All arguments must be tables.")
		for key, child in pairs(value) do
			result[key] = result[key] == nil and child or resolver(result[key], child)
		end
	end
	return result
end

---Recursively merges nested tables instead of overwriting child dictionaries.
---@param ... table One or more nested dictionaries to merge.
---@return table A deep-merged dictionary.
function dict.deep_merge(...)
	local result = {}
	for _, value in ipairs({ ... }) do
		assert(is_mapping(value), "All arguments must be tables.")
		for key, child in pairs(value) do
			if key ~= "__prototype" then
				if is_mapping(result[key]) and is_mapping(child) then
					result[key] = dict.deep_merge(result[key], child)
				else
					result[key] = copy_table(child, true)
				end
			end
		end
	end
	return result
end

---Groups a list of records by the value found at the given key.
---@param items table A list of record tables.
---@param key string|number The record field name or index to group by.
---@return table A dictionary keyed by the grouped values.
function dict.group_by(items, key)
	local result = {}
	for _, item in ipairs(items) do
		if item[key] ~= nil then
			result[item[key]] = result[item[key]] or {}
			_tbl.insert(result[item[key]], item)
		end
	end
	return result
end

---Returns a new dictionary containing only the requested keys.
---@param value table The source dictionary.
---@param keys table The list of keys to keep.
---@return table A filtered dictionary containing only those keys.
function dict.pick(value, keys)
	local wanted, result = {}, {}
	for _, key in ipairs(keys) do wanted[key] = true end
	for key, child in pairs(value) do if wanted[key] then result[key] = child end end
	return result
end

---Returns a new dictionary without any of the excluded keys.
---@param value table The source dictionary.
---@param keys table The list of keys to remove.
---@return table A dictionary with the excluded keys removed.
function dict.omit(value, keys)
	local unwanted, result = {}, {}
	for _, key in ipairs(keys) do unwanted[key] = true end
	for key, child in pairs(value) do if not unwanted[key] then result[key] = child end end
	return result
end

---Lists the keys of a dictionary as a plain Lua array.
---@param value table The dictionary to inspect.
---@return table An array of keys.
function dict.keys(value)
	return _tbl.toNative(_tbl.keys(value))
end

---Lists the values of a dictionary as a plain Lua array.
---@param value table The dictionary to inspect.
---@return table An array of values.
function dict.values(value)
	return _tbl.toNative(_tbl.values(value))
end

---Determines whether a table behaves like a dense numeric array.
---@param value any The value to inspect.
---@return boolean true when the table is a valid array-like dictionary.
function dict.is_array(value)
	if type(value) ~= "table" then return false end
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
		count = math.max(count, key)
	end
	for index = 1, count do if value[index] == nil then return false end end
	return true
end

---Keeps only entries whose keys satisfy the predicate.
---@param value table The source dictionary.
---@param predicate function A function that accepts a key and returns true to keep it.
---@return table A dictionary containing only matching keys.
function dict.filter_keys(value, predicate)
	local result = {}
	for key, child in pairs(value) do if predicate(key) then result[key] = child end end
	return result
end

---Keeps only entries whose values satisfy the predicate.
---@param value table The source dictionary.
---@param predicate function A function that accepts a value and returns true to keep it.
---@return table A dictionary containing only matching values.
function dict.filter_by_value(value, predicate)
	local result = {}
	for key, child in pairs(value) do if predicate(child) then result[key] = child end end
	return result
end

---Filters a dictionary using a callback that receives both key and value.
---@param value table The source dictionary.
---@param predicate function A callback receiving key and value.
---@return table A filtered dictionary.
function dict.filter_dict(value, predicate)
	local result = {}
	for key, child in pairs(value) do if predicate(key, child) then result[key] = child end end
	return result
end

---Splits a dictionary into matching and non-matching tables.
---@param value table The source dictionary.
---@param predicate function A callback receiving key and value.
---@return table matching The entries that matched.
---@return table non_matching The entries that did not match.
function dict.partition_dict(value, predicate)
	local matching, non_matching = {}, {}
	for key, child in pairs(value) do
		(predicate(key, child) and matching or non_matching)[key] = child
	end
	return matching, non_matching
end

---Transforms each dictionary value and returns a new dictionary with the same keys.
---@param value table The source dictionary.
---@param callback function A function invoked with each value.
---@return table A transformed dictionary.
function dict.map_values(value, callback)
	local result = {}
	for key, child in pairs(value) do result[key] = callback(child) end
	return result
end

---Renames dictionary keys using a callback while preserving each original value.
---@param value table The source dictionary.
---@param callback function A function transforming each key.
---@return table A dictionary with rewritten keys.
function dict.map_keys(value, callback)
	local result = {}
	for key, child in pairs(value) do result[callback(key)] = child end
	return result
end

---Sorts a dictionary by key or value and returns a new ordered dictionary.
---@param value table The dictionary to sort.
---@param by string Whether to sort by "key" or "value".
---@param reverse boolean|nil Whether to reverse the ordering.
---@return table A sorted dictionary.
function dict.sort_dict(value, by, reverse)
	by, reverse = by or "key", reverse or false
	assert(by == "key" or by == "value", "'by' must be either 'key' or 'value'.")
	local entries = {}
	for key, child in pairs(value) do _tbl.insert(entries, { key, child }) end
	_tbl.sort(entries, function(left, right)
		local a, b = left[by == "key" and 1 or 2], right[by == "key" and 1 or 2]
		return reverse and a > b or a < b
	end)
	local result = {}
	for _, entry in ipairs(entries) do result[entry[1]] = entry[2] end
	return result
end

---Renames keys according to a mapping, optionally keeping keys that do not match a rename.
---@param value table The source dictionary.
---@param names table A map of old keys to new keys.
---@param keep_unmatched boolean|nil Whether unmatched keys should remain unchanged.
---@return table A dictionary with renamed keys.
function dict.rename_keys(value, names, keep_unmatched)
	if keep_unmatched == nil then keep_unmatched = true end
	local result = {}
	for key, child in pairs(value) do
		if keep_unmatched or names[key] ~= nil then result[names[key] or key] = child end
	end
	return result
end

---Groups items by a computed key returned from a callback function.
---@param items table An array of items to group.
---@param callback function A function returning the group key for each item.
---@return table A dictionary of grouped items.
function dict.group_by_function(items, callback)
	local result = {}
	for _, item in ipairs(items) do
		local key = callback(item)
		result[key] = result[key] or {}
			_tbl.insert(result[key], item)
	end
	return result
end

---Traverses a nested dictionary and records each leaf value with its key path.
---@param value table The dictionary to walk.
---@return table A list of { path, value } entries for each leaf.
function dict.walk_dict(value)
	local result = {}
	local function walk(current, path)
		if is_mapping(current) then
			for key, child in pairs(current) do
				local next_path = copy_table(path, false)
				_tbl.insert(next_path, key)
				walk(child, next_path)
			end
		else
			 _tbl.insert(result, { path, current })
		end
	end
	walk(value, {})
	return result
end

---Recursively transforms every leaf value in a nested dictionary using the callback.
---@param value table The dictionary to transform.
---@param callback function A function called with each leaf value.
---@return table A transformed dictionary.
function dict.transform_recursive(value, callback)
	local result = {}
	for key, child in pairs(value) do
		result[key] = is_mapping(child) and dict.transform_recursive(child, callback) or callback(child)
	end
	return result
end

---Lazily creates a value for a key if it does not already exist and returns it.
---@param value table The target dictionary.
---@param key any The key to access.
---@param factory function A factory function to create the value when missing.
---@return any The existing or created value.
function dict.get_or_set(value, key, factory)
	if value[key] == nil then value[key] = factory() end
	return value[key]
end

---Lazily creates a nested value at a dot-path and returns the created object.
---@param value table The target dictionary.
---@param path string|table A dotted path or key array.
---@param factory function A factory function for the missing nested value.
---@param separator string|nil The path separator for string paths.
---@return any The existing or created nested value.
function dict.get_or_set_path(value, path, factory, separator)
	local current = dict.get_path(value, path, nil, separator)
	if current ~= nil then return current end
	local created = factory()
	dict.set_path(value, path, created, separator)
	return created
end

---Copies a dictionary and fills in any missing keys with the supplied default value.
---@param value table The source dictionary.
---@param keys table The keys that must exist after copying.
---@param default any The fallback value for missing keys.
---@return table A copy with default values inserted as needed.
function dict.ensure_keys(value, keys, default)
	local result = copy_table(value, false)
	for _, key in ipairs(keys) do if result[key] == nil then result[key] = default end end
	return result
end

---Creates a dictionary from a list of key/value pairs, optionally rejecting duplicates.
---@param pairs table A list of { key, value } pairs.
---@param strict boolean|nil Whether duplicate keys should raise an error.
---@return table A dictionary built from the pairs.
function dict.from_pairs(pairs, strict)
	local result = {}
	for _, pair in ipairs(pairs) do
		if strict and result[pair[1]] ~= nil then error("Duplicate key: " .. tostring(pair[1])) end
		result[pair[1]] = pair[2]
	end
	return result
end

---Swaps dictionary keys and values, assuming each value is unique.
---@param value table The dictionary to invert.
---@return table A dictionary with keys and values swapped.
function dict.invert_dict(value)
	local result = {}
	for key, child in pairs(value) do result[child] = key end
	return result
end

---Inverts a dictionary while preserving multiple original keys that resolve to the same value.
---@param value table The dictionary to invert.
---@return table A multi-map dictionary from values to their original keys.
function dict.invert_multidict(value)
	local result = {}
	for key, child in pairs(value) do
		result[child] = result[child] or {}
		 _tbl.insert(result[child], key)
	end
	return result
end

---Flattens nested dictionaries into a single-level map using a path separator.
---@param value table The nested dictionary to flatten.
---@param parent_key string|nil The parent path prefix used during recursion.
---@param separator string|nil The path separator to use between nested keys.
---@return table A flattened dictionary keyed by dot-path strings.
function dict.flatten_dict(value, parent_key, separator)
	parent_key, separator = parent_key or "", separator or "."
	local result = {}
	for key, child in pairs(value) do
		local new_key = parent_key == "" and tostring(key) or parent_key .. separator .. tostring(key)
		if is_mapping(child) then
			for nested_key, nested_value in pairs(dict.flatten_dict(child, new_key, separator)) do result[nested_key] = nested_value end
		else result[new_key] = child end
	end
	return result
end

---Rebuilds nested dictionaries from flattened dot-path entries.
---@param value table A flattened dictionary keyed by dot-path strings.
---@param separator string|nil The separator used in those keys.
---@return table A nested dictionary reconstructed from the flattened paths.
function dict.unflatten_dict(value, separator)
	separator = separator or "."
	local result = {}
	for path, child in pairs(value) do
		assert(type(path) == "string", "Unflattened keys must be strings.")
		local current = result
		local parts = {}
		for part in path:gmatch("[^" .. separator .. "]+") do _tbl.insert(parts, part) end
		for index = 1, #parts - 1 do
			if current[parts[index]] == nil then current[parts[index]] = {} end
			assert(is_mapping(current[parts[index]]), "Conflicting path: " .. path)
			current = current[parts[index]]
		end
		current[parts[#parts]] = child
	end
	return result
end

---Reads a nested value by path, returning the default when a segment is missing.
---@param value table The dictionary to read from.
---@param path string|table A dotted-path string or array of keys.
---@param default any The fallback value used if the path is missing.
---@param separator string|nil The path separator used for string paths.
---@return any The resolved value or the fallback default.
function dict.get_path(value, path, default, separator)
	separator = separator or "."
	local parts = type(path) == "string" and {} or path
	if type(path) == "string" then for part in path:gmatch("[^" .. separator .. "]+") do _tbl.insert(parts, part) end end
	local current = value
	for _, key in ipairs(parts) do
		if not is_mapping(current) or current[key] == nil then return default end
		current = current[key]
	end
	return current
end

---Returns true if the nested path exists and resolves to a non-nil value.
---@param value table The dictionary to inspect.
---@param path string|table A dotted path or key array.
---@param separator string|nil The path separator for string paths.
---@return boolean true when the path exists.
function dict.has_path(value, path, separator)
	local marker = {}
	return dict.get_path(value, path, marker, separator) ~= marker
end

---Writes a value into a nested dictionary path, creating intermediate tables as needed.
---@param value table The target dictionary.
---@param path string|table A dotted path or key array.
---@param child any The value to store at that path.
---@param separator string|nil The delimiter for string paths.
---@return nil
function dict.set_path(value, path, child, separator)
	separator = separator or "."
	local parts = type(path) == "string" and {} or path
	if type(path) == "string" then for part in path:gmatch("[^" .. separator .. "]+") do _tbl.insert(parts, part) end end
	assert(#parts > 0, "Path must contain at least one non-empty key.")
	local current = value
	for index = 1, #parts - 1 do
		if not is_mapping(current[parts[index]]) then current[parts[index]] = {} end
		current = current[parts[index]]
	end
	current[parts[#parts]] = child
end

---Creates a copied dictionary where the nested path value is transformed by the callback.
---@param value table The source dictionary.
---@param path string|table A dotted path or key array.
---@param callback function A function to apply to the current path value.
---@param default any The default value when the path is missing.
---@param separator string|nil The path separator for string paths.
---@return table A new dictionary with the updated path value.
function dict.update_path(value, path, callback, default, separator)
	local result = dict.deep_copy(value)
	dict.set_path(result, path, callback(dict.get_path(result, path, default, separator)), separator)
	return result
end

---Removes a key recursively from nested dictionaries and returns the pruned copy.
---@param value table The dictionary to prune.
---@param target_key any The key to remove from nested levels.
---@return table A copy of the dictionary without the target key.
function dict.deep_delete(value, target_key)
	local result = {}
	for key, child in pairs(value) do if key ~= target_key then result[key] = is_mapping(child) and dict.deep_delete(child, target_key) or child end end
	return result
end

---Searches nested dictionaries for every matching key and collects the associated values.
---@param value table The dictionary to search.
---@param target_key any The key name to look for recursively.
---@return table A list of values stored under matching keys.
function dict.search_keys(value, target_key)
	local result = {}
	local function search(current)
		for key, child in pairs(current) do
			if key == target_key then _tbl.insert(result, child) end
			if is_mapping(child) then search(child) end
		end
	end
	search(value)
	return result
end

---Lists all flattened dictionary keys from nested objects.
---@param value table The dictionary to flatten.
---@param separator string|nil The delimiter used in the flattened keys.
---@return table A list of flattened keys.
function dict.keys_recursive(value, separator)
	local result = {}
	for key in pairs(dict.flatten_dict(value, "", separator)) do _tbl.insert(result, key) end
	return result
end

---Merges user-supplied options over defaults while preserving nested structure.
---@param default table The default option dictionary.
---@param user table|nil Optional user-provided values.
---@return table A merged defaults-plus-user dictionary.
function dict.params(default, user)
	return dict.deep_merge(default, user or {})
end

---Validates a user parameter dictionary against a default schema and required rules.
---@param user table The incoming values to validate.
---@param default table The default schema to compare against.
---@param options table|nil Validation options, including required keys, extras, and validators.
---@return nil Raises an error when validation fails.
function dict.validate_params(user, default, options)
	assert(is_mapping(user) and is_mapping(default), "User and default parameters must be tables.")
	options = options or {}
	local extras, allowed = {}, {}
	for _, key in ipairs(options.extras or {}) do extras[key] = true end
	for key in pairs(default) do allowed[key] = true end
	for key in pairs(extras) do allowed[key] = true end
	if not options.allow_unknown then
		local function validate_keys(current, schema, path, is_root)
			for key, child in pairs(current) do
				if key ~= "__prototype" then
					local child_path = path == "" and tostring(key) or path .. "." .. tostring(key)
					local extra = extras[child_path] or (is_root and extras[key]) or extras[path]
					if schema[key] == nil and not extra then error("Invalid parameter: " .. child_path) end
					if not extra and is_mapping(child) and is_mapping(schema[key]) then
						validate_keys(child, schema[key], child_path, false)
					end
				end
			end
		end
		validate_keys(user, default, "", true)
	end
	for _, key in ipairs(options.required or {}) do if user[key] == nil then error("Missing required parameter: " .. tostring(key)) end end
	for key, validator in pairs(options.validators or {}) do
		assert(type(validator) == "function", "Validator must be callable.")
		if user[key] ~= nil and not validator(user[key]) then error("Invalid value for parameter " .. tostring(key)) end
	end
end

---Validates parameters and then returns a dictionary object built from merged defaults and user input.
---@param default table The default parameter schema.
---@param user table|nil User-supplied options to merge on top of defaults.
---@param options table|nil Validation configuration for required and custom checks.
---@return table A validated dictionary object.
function dict.strict_params(default, user, options)
	user = user or {}
	dict.validate_params(user, default, options)
	return dict(dict.deep_merge(default, user))
end

local function json_encode(value)
	if value == nil then return "null" end
	if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
	if type(value) == "string" then return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub("\n", "\\n") .. '"' end
	local parts, array = {}, dict.is_array(value)
	local length = #value
	if array then for index = 1, length do _tbl.insert(parts, json_encode(value[index])) end
	else for key, child in pairs(value) do
		if key ~= "__prototype" then
			_tbl.insert(parts, json_encode(tostring(key)) .. ":" .. json_encode(child))
		end
	end end
	return (array and "[" or "{") .. _tbl.concat(parts, ",") .. (array and "]" or "}")
end

---Serializes a dictionary-like Lua value into compact JSON text.
---@param value any The value to encode.
---@return string JSON-encoded text.
function dict.to_json(value) return json_encode(value) end

---Loads a JSON file and parses it into a dictionary table.
---@param file_path string The path to the JSON file to load.
---@return table A parsed dictionary object.
function dict.load_json_file(file_path)
	local file, reason = io.open(file_path, "r")
	if not file then error(reason) end
	local contents = file:read("*a")
	file:close()
	return dict.from_json(contents)
end

---Writes a dictionary to disk as JSON using the library's compact encoder.
---@param value table The value to serialize.
---@param file_path string The destination path for the JSON file.
---@param indent any Unused compatibility argument.
---@param sort_keys any Unused compatibility argument.
---@return nil
function dict.save_json_file(value, file_path, indent, sort_keys)
	local file, reason = io.open(file_path, "w")
	if not file then error(reason) end
	file:write(dict.to_json(value), "\n")
	file:close()
end

---Parses JSON text into a Lua dictionary, handling nested objects and arrays.
---@param value string The JSON text to parse.
---@return table A dictionary built from the JSON payload.
function dict.from_json(value)
	local index = 1
	local function whitespace()
		local next_index = value:find("%S", index)
		index = next_index or (#value + 1)
	end
	local parse_value
	local function parse_string()
		index = index + 1
		local result = {}
		while index <= #value and value:sub(index, index) ~= '"' do
			if value:sub(index, index) == "\\" then
				index = index + 1
				local escaped = value:sub(index, index)
				local replacements = { ["n"] = "\n", ["r"] = "\r", ["t"] = "\t", ["b"] = "\b", ["f"] = "\f" }
				_tbl.insert(result, replacements[escaped] or escaped)
			else
				 _tbl.insert(result, value:sub(index, index))
			end
			index = index + 1
		end
		assert(value:sub(index, index) == '"', "Invalid JSON string.")
		index = index + 1
		return _tbl.concat(result)
	end
	local function parse_array()
		index = index + 1
		local result = {}
		whitespace()
		if value:sub(index, index) == "]" then index = index + 1; return result end
		while true do
			_tbl.insert(result, parse_value())
			whitespace()
			local delimiter = value:sub(index, index)
			index = index + 1
			if delimiter == "]" then return result end
			assert(delimiter == ",", "Invalid JSON array.")
			whitespace()
		end
	end
	local function parse_object()
		index = index + 1
		local result = {}
		whitespace()
		if value:sub(index, index) == "}" then index = index + 1; return result end
		while true do
			assert(value:sub(index, index) == '"', "JSON object keys must be strings.")
			local key = parse_string()
			whitespace()
			assert(value:sub(index, index) == ":", "Invalid JSON object.")
			index = index + 1
			result[key] = parse_value()
			whitespace()
			local delimiter = value:sub(index, index)
			index = index + 1
			if delimiter == "}" then return result end
			assert(delimiter == ",", "Invalid JSON object.")
			whitespace()
		end
	end
	parse_value = function()
		whitespace()
		local character = value:sub(index, index)
		if character == '"' then return parse_string() end
		if character == "[" then return parse_array() end
		if character == "{" then return parse_object() end
		if value:sub(index, index + 3) == "true" then index = index + 4; return true end
		if value:sub(index, index + 4) == "false" then index = index + 5; return false end
		if value:sub(index, index + 3) == "null" then index = index + 4; return nil end
		local number = value:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
		assert(number and number ~= "", "Invalid JSON value.")
		index = index + #number
		return tonumber(number)
	end
	local result = parse_value()
	whitespace()
	assert(index > #value, "Invalid JSON trailing content.")
	assert(is_mapping(result), "JSON root must be an object.")
	return result
end

---Removes nil values from a dictionary, optionally cleaning nested maps as well.
---@param value table The dictionary to clean.
---@param recursive boolean|nil Whether nested tables should also be cleaned.
---@return table A dictionary without nil values.
function dict.remove_none(value, recursive)
	local result = {}
	for key, child in pairs(value) do if child ~= nil then result[key] = recursive and is_mapping(child) and dict.remove_none(child, true) or child end end
	return result
end

---Counts how many times each value appears in an array-like list.
---@param values table The list to count.
---@return table A dictionary of value -> count.
function dict.count_values(values)
	local result = {}
	for _, value in ipairs(values) do result[value] = (result[value] or 0) + 1 end
	return result
end

---Removes empty nested dictionaries and nil values from a structure.
---@param value table The dictionary to prune.
---@param recursive boolean|nil Whether nested tables should be pruned as well.
---@return table A pruned dictionary.
function dict.prune_empty(value, recursive)
	if recursive == nil then recursive = true end
	local result = {}
	for key, child in pairs(value) do
		if recursive and is_mapping(child) then child = dict.prune_empty(child, true) end
		if child ~= nil and not (is_mapping(child) and next(child) == nil) then result[key] = child end
	end
	return result
end

---Groups original keys by a transformed value computed from each entry's data.
---@param value table The source dictionary.
---@param callback function A function converting each value into a grouping key.
---@return table A dictionary of grouped keys.
function dict.invert_by(value, callback)
	local result = {}
	for key, child in pairs(value) do
		local computed = callback(child)
		result[computed] = result[computed] or {}
		 _tbl.insert(result[computed], key)
	end
	return result
end

---Recursively compares two values and returns true only when their nested contents match.
---@param left any The left-hand value to compare.
---@param right any The right-hand value to compare.
---@return boolean true when the values are deeply equal.
function dict.deep_equal(left, right)
	if is_mapping(left) and is_mapping(right) then
		for key, value in pairs(left) do if not dict.deep_equal(value, right[key]) then return false end end
		for key in pairs(right) do if left[key] == nil then return false end end
		return true
	end
	return left == right
end

---Checks whether every key/value pair in the subset is also present in the superset.
---@param subset table The smaller dictionary to test.
---@param superset table The larger dictionary to compare against.
---@return boolean true when subset is contained within superset.
function dict.is_subset(subset, superset)
	for key, value in pairs(subset) do if superset[key] ~= value then return false end end
	return true
end

---Compares two dictionaries and reports added, removed, and changed keys.
---@param left table The original dictionary.
---@param right table The updated dictionary.
---@return table A summary with added, removed, and changed entries.
function dict.dict_diff(left, right)
	local result = { added = {}, removed = {}, changed = {} }
	for key, value in pairs(right) do if left[key] == nil then result.added[key] = value elseif left[key] ~= value then result.changed[key] = value end end
	for key, value in pairs(left) do if right[key] == nil then result.removed[key] = value end end
	return result
end

---Recursively compares nested dictionaries and reports differences at each level.
---@param left table The original nested dictionary.
---@param right table The updated nested dictionary.
---@return table A deep diff containing added, removed, and changed entries.
function dict.deep_dict_diff(left, right)
	local result = { added = {}, removed = {}, changed = {} }
	for key, value in pairs(right) do
		if left[key] == nil then result.added[key] = value
		elseif is_mapping(left[key]) and is_mapping(value) then
			local nested = dict.deep_dict_diff(left[key], value)
			if next(nested.added) or next(nested.removed) or next(nested.changed) then result.changed[key] = nested end
		elseif left[key] ~= value then result.changed[key] = { from = left[key], to = value } end
	end
	for key, value in pairs(left) do if right[key] == nil then result.removed[key] = value end end
	return result
end

---Convenience alias for flattening a nested dictionary into a single-level map.
---@param value table The dictionary to flatten.
---@return table A flattened dictionary keyed by path strings.
function dict.flatten(value) return dict.flatten_dict(value) end

---Creates a read-only proxy around a table, optionally freezing nested tables too.
---@param value table The table to freeze.
---@param recursive boolean|nil Whether nested tables should also be frozen.
---@return table A read-only proxy around the input table.
function dict.freeze(value, recursive)
	assert(type(value) == "table", "Only tables can be frozen.")
	local proxy = {}
	local frozen = {}
	for key, child in pairs(value) do
		frozen[key] = recursive and type(child) == "table" and dict.freeze(child, true) or child
	end
	return setmetatable(proxy, {
		__index = frozen,
		__newindex = function() error("Cannot modify a frozen table.", 2) end,
		__pairs = function() return pairs(frozen) end,
		__len = function() return #frozen end,
	})
end

dict.readonly = dict.freeze

---Alias for deep-copying a dictionary value.
---@param this table The dictionary to copy.
---@return table A deep copy of the dictionary.
function dict.copy(this)
	return dict.deep_copy(this)
end

---Creates a dictionary object from an optional initial table.
---@param initial table|nil The starting values to seed the dictionary with.
---@return table A dictionary object instance.
function dict.Dictionary(initial)
	return dict(initial or {})
end

for _, key in ipairs(dict.keys(dict)) do
	dict.prototype[key] = dict[key]
end

getmetatable(dict.prototype).__tostring = function(this)
	return json_encode(this)
end

return dict
