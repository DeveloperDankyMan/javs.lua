local _javs = require(game:GetService("ServerStorage"):WaitForChild("javs"))
local _Object = _javs.Object

local function concat(values, separator, first, last)
    if type(values) ~= "table" then return "" end
    separator = separator or ""
    first = first or 1
    last = last or #values
    local result = ""
    for index = first, last do
        if index > first then result = result .. separator end
        result = result .. tostring(values[index])
    end
    return result
end

local function insert(values, position, value)
    if type(values) ~= "table" then return end
    if value == nil then value, position = position, #values + 1 end
    position = position or #values + 1
    for index = #values, position, -1 do values[index + 1] = values[index] end
    values[position] = value
end

local function remove(values, position)
    if type(values) ~= "table" then return end
    position = position or #values
    local removed = values[position]
    for index = position, #values - 1 do values[index] = values[index + 1] end
    values[#values] = nil
    return removed
end

local function sort(values, compare)
    if type(values) ~= "table" then return values end
    local function before(left, right)
        if compare then return compare(left, right) end
        return tostring(left) < tostring(right)
    end
    for index = 2, #values do
        local value = values[index]
        local previous = index - 1
        while previous > 0 and before(value, values[previous]) do
            values[previous + 1] = values[previous]
            previous = previous - 1
        end
        values[previous + 1] = value
    end
    return values
end

local function pack(...)
    local values = { ... }
    values.n = select("#", ...)
    return values
end

local function unpackValues(values, first, last)
    if first > last then return end
    return values[first], unpackValues(values, first + 1, last)
end

local function unpackTable(values, first, last)
    if type(values) ~= "table" then return end
    return unpackValues(values, first or 1, last or values.n or #values)
end

local function move(values, first, last, target, destination)
    if type(values) ~= "table" then return end
    destination = destination or values
    local count = last - first + 1
    if destination == values and target > first and target <= last then
        for offset = count - 1, 0, -1 do destination[target + offset] = values[first + offset] end
    else
        for offset = 0, count - 1 do destination[target + offset] = values[first + offset] end
    end
    return destination
end

local _table 
_table = _Object("table", function()
    local members = {}

    members.init = function(this, initial)
        if type(initial) ~= "table" then return end
        for key, value in pairs(initial) do
            if key ~= "__prototype" then 
                this[key] = value
             end
        end
    end

    return members
end)

---@class table

---Creates a new wrapped table from an initial list or map of values.
---@param initial table|nil The source data to seed the new table with.
---@return table wrapped A newly wrapped table instance.
function _table.from(initial)
    return _table(initial)
end

---Creates a shallow copy of a table while preserving the wrapper type.
---@param initial table The table to duplicate.
---@return table wrapped A shallow copy of the original table.
function _table.clone(initial)
    return _table(initial)
end

---Checks whether any entry equals the requested value.
---@param this table The table to inspect.
---@param wanted any The value to look for.
---@return boolean true when the value is present.
function _table.contains(this, wanted)
    for key, value in pairs(this) do
        if key ~= "__prototype" and value == wanted then return true end
    end
    return false
end

---Finds the first entry whose value satisfies the predicate.
---@param this table The table to search.
---@param predicate function A function receiving value, key, and source table.
---@return any value The matching value, if any.
---@return any key The matching key, if any.
function _table.find(this, predicate)
    for key, value in pairs(this) do
        if key ~= "__prototype" and predicate(value, key, this) then return value, key end
    end
    return nil, nil
end

---Maps each value through a callback and returns a new wrapped table.
---@param this table The source table.
---@param transform function A function called with value, key, and source table.
---@return table wrapped A transformed table.
function _table.map(this, transform)
    local result = {}
    for key, value in pairs(this) do
        if key ~= "__prototype" then result[key] = transform(value, key, this) end
    end
    return _table(result)
end

---Returns a new table containing only values that satisfy the predicate.
---@param this table The source table.
---@param predicate function A callback returning true for entries to keep.
---@return table wrapped The filtered table.
function _table.filter(this, predicate)
    local result = {}
    if #this > 0 then
        for key, value in ipairs(this) do
            if predicate(value, key, this) then result[#result + 1] = value end
        end
    else
        for key, value in pairs(this) do
            if key ~= "__prototype" and predicate(value, key, this) then result[key] = value end
        end
    end
    return _table(result)
end

---Collects the table's keys into a new array-like table.
---@param this table The table to inspect.
---@return table wrapped A wrapped array of keys.
function _table.keys(this)
    local result = {}
    for key in pairs(this) do
        if key ~= "__prototype" then result[#result + 1] = key end
    end
    return _table(result)
end

---Collects all stored values into a new array-like table.
---@param this table The table to inspect.
---@return table wrapped A wrapped array of values.
function _table.values(this)
    local result = {}
    for key, value in pairs(this) do
        if key ~= "__prototype" then result[#result + 1] = value end
    end
    return _table(result)
end

---Removes every non-prototype entry from the table in place.
---@param this table The table to clear.
---@return table this The cleared table.
function _table.clear(this)
    for key in pairs(this) do
        if key ~= "__prototype" then this[key] = nil end
    end
    return this
end

---Returns true if at least one value passes the predicate.
---@param this table The table to inspect.
---@param predicate function A callback receiving value, key, and source table.
---@return boolean true when at least one entry matches.
function _table.some(this, predicate)
    for key, value in pairs(this) do
        if key ~= "__prototype" and predicate(value, key, this) then return true end
    end
    return false
end

---Returns true only when every value satisfies the predicate.
---@param this table The table to inspect.
---@param predicate function A callback receiving value, key, and source table.
---@return boolean true when every entry matches.
function _table.every(this, predicate)
    for key, value in pairs(this) do
        if key ~= "__prototype" and not predicate(value, key, this) then return false end
    end
    return true
end

---Reduces the table to a single accumulated value.
---@param this table The table to reduce.
---@param reducer function A reducer taking accumulator, current value, key, and source table.
---@param initial any The starting accumulator value.
---@return any The final reduced value.
function _table.reduce(this, reducer, initial)
    local result = initial
    local started = initial ~= nil
    for key, value in pairs(this) do
        if key ~= "__prototype" then
            if not started then
                result, started = value, true
            else
                result = reducer(result, value, key, this)
            end
        end
    end
    return result
end

---Counts the number of entries, optionally restricted by a predicate.
---@param this table The table to count.
---@param predicate function|nil An optional callback used to select entries.
---@return number The number of matching entries.
function _table.count(this, predicate)
    local result = 0
    for key, value in pairs(this) do
        if key ~= "__prototype" and (not predicate or predicate(value, key, this)) then result = result + 1 end
    end
    return result
end

---Checks whether the given key exists in the table and is not nil.
---@param this table The table to inspect.
---@param key any The key to look for.
---@return boolean true when the key has a non-nil value.
function _table.has(this, key)
    return rawget(this, key) ~= nil
end

---Returns true when the table contains no entries.
---@param this table The table to inspect.
---@return boolean true when the table is empty.
function _table.isEmpty(this)
    return _table.count(this) == 0
end

---Splits the table into matching and non-matching tables.
---@param this table The table to partition.
---@param predicate function A callback receiving value, key, and source table.
---@return table matching Entries that satisfy the predicate.
---@return table non_matching Entries that do not satisfy the predicate.
function _table.partition(this, predicate)
    return _table.filter(this, predicate), _table.filter(this, function(value, key, source)
        return not predicate(value, key, source)
    end)
end

---Returns the number of entries in the table.
---@param this table The table to measure.
---@return number The number of entries.
function _table.size(this)
    return _table.count(this)
end

---Checks whether the table behaves like a dense numeric array.
---@param this table The table to inspect.
---@return boolean true when all keys are consecutive positive integers.
function _table.isArray(this)
    if type(this) ~= "table" then return false end
    local count = 0
    for key in pairs(this) do
        if key ~= "__prototype" then
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
            count = count + 1
        end
    end
    return count == #this
end

---Alias for contains, used to check whether a value is present.
---@param this table The table to inspect.
---@param wanted any The value to look for.
---@return boolean true when the value is present.
function _table.includes(this, wanted)
    return _table.contains(this, wanted)
end

---Returns the index of the first matching value, or -1 when absent.
---@param this table The table to search.
---@param wanted any The value to look for.
---@return any The matching index or -1.
function _table.indexOf(this, wanted)
    for key, value in pairs(this) do
        if key ~= "__prototype" and value == wanted then return key end
    end
    return -1
end

---Returns the first array element, if it exists.
---@param this table The array to inspect.
---@return any The first element.
function _table.first(this)
    return this[1]
end

---Returns the last array element, if it exists.
---@param this table The array to inspect.
---@return any The last element.
function _table.last(this)
    return this[#this]
end

---Returns a new table with the array order reversed.
---@param this table The array to reverse.
---@return table wrapped A reversed wrapped array.
function _table.reverse(this)
    local result = {}
    for index = #this, 1, -1 do result[#result + 1] = this[index] end
    return _table(result)
end

---Extracts a contiguous slice of the array and returns it as a new table.
---@param this table The source array.
---@param first number|nil The first index to include.
---@param last number|nil The last index to include.
---@return table wrapped A wrapped array containing the selected entries.
function _table.slice(this, first, last)
    local result = {}
    first = first or 1
    last = last or #this
    if first < 0 then first = #this + first + 1 end
    if last < 0 then last = #this + last + 1 end
    for index = first, last do result[#result + 1] = this[index] end
    return _table(result)
end

---Sums all values, or selected values when a selector is provided.
---@param this table The table to sum.
---@param selector function|nil An optional callback that returns each value to sum.
---@return number The total sum.
function _table.sum(this, selector)
    local result = 0
    for key, value in pairs(this) do
        if key ~= "__prototype" then result = result + (selector and selector(value, key, this) or value) end
    end
    return result
end

---Removes duplicate values while preserving the first occurrence order.
---@param this table The table whose values should be deduplicated.
---@return table wrapped A wrapped table of unique values.
function _table.unique(this)
    local result, seen = {}, {}
    for key, value in pairs(this) do
        if key ~= "__prototype" and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    return _table(result)
end

---Merges one or more source tables into a copy of this table.
---@param this table The base table.
---@param ... any One or more tables to merge into the base.
---@return table wrapped A merged copy of the original table.
function _table.merge(this, ...)
    local result = _table.clone(this)
    for index = 1, select("#", ...) do
        local source = select(index, ...)
        if type(source) == "table" then
            for key, value in pairs(source) do
                if key ~= "__prototype" then result[key] = value end
            end
        end
    end
    return result
end

---Flattens nested array tables to a chosen depth and returns the flattened result.
---@param this table The nested array to flatten.
---@param depth number|nil The maximum nesting depth to remove.
---@return table wrapped A flattened wrapped array.
function _table.flatten(this, depth)
    local result = {}
    depth = depth or math.huge
    local function append(value, level)
        if level > 0 and type(value) == "table" and _table.isArray(value) then
            for index = 1, #value do append(value[index], level - 1) end
        else
            result[#result + 1] = value
        end
    end
    for index = 1, #this do append(this[index], depth) end
    return _table(result)
end

---Converts the wrapped table object back into a plain Lua table.
---@param this table The wrapped table to convert.
---@return table A plain Lua table.
function _table.toNative(this)
    local result = {}
    for key, value in pairs(this) do
        if key ~= "__prototype" then result[key] = value end
    end
    return result
end

local function deepClone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        if key ~= "__prototype" then result[deepClone(key, seen)] = deepClone(child, seen) end
    end
    return result
end

---Recursively clones nested tables so the copy does not share child references.
---@param this table The nested table to clone.
---@return table wrapped A deeply cloned wrapped table.
function _table.deepClone(this)
    return _table(deepClone(this))
end

---Joins table entries into a string using an optional separator and range.
---@param values table The values to join.
---@param separator string|nil The separator between values.
---@param first number|nil The first index to include.
---@param last number|nil The last index to include.
---@return string The concatenated string.
function _table.concat(values, separator, first, last)
    return concat(values, separator, first, last)
end

---Inserts a value into an array table at a position and shifts later entries.
---@param values table The array to modify.
---@param position number|any The insertion position or value when omitted.
---@param value any|nil The value to insert.
---@return nil
function _table.insert(values, position, value)
    return insert(values, position, value)
end

---Removes and returns the element at the given position from an array table.
---@param values table The array to modify.
---@param position number|nil The position to remove, defaulting to the last entry.
---@return any The removed value.
function _table.remove(values, position)
    return remove(values, position)
end

---Sorts an array table in place using an optional comparator.
---@param values table The array to sort.
---@param compare function|nil A comparator returning true when the first value comes first.
---@return table The sorted array.
function _table.sort(values, compare)
    return sort(values, compare)
end

---Packages a variadic argument list into a table with an n field.
---@param ... any Values to package.
---@return table The packed values and their original count.
function _table.pack(...)
    return pack(...)
end

---Unpacks a table range back into separate values, similar to Lua's unpack.
---@param values table The table to unpack.
---@param first number|nil The first index to unpack.
---@param last number|nil The last index to unpack.
---@return ... any The unpacked values.
function _table.unpack(values, first, last)
    return unpackTable(values, first, last)
end

---Moves a contiguous range of array entries to a new position.
---@param values table The source array.
---@param first number The first source index.
---@param last number The last source index.
---@param target number The destination index.
---@param destination table|nil The destination array, defaulting to the source.
---@return table The destination array.
function _table.move(values, first, last, target, destination)
    return move(values, first, last, target, destination)
end

for _, key in ipairs(_table.keys(_table)) do
    _table.prototype[key] = _table[key]
end

return _table
