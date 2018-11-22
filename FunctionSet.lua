--- TODO!

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local assert = assert
local error = error
local getmetatable = getmetatable
local pairs = pairs
local pcall = pcall
local rawequal = rawequal
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")

-- Cached module references --
local _GetState_

-- Exports --
local M = {}

--
--
--

local State = {}

local Sets = {}

local Work

--- DOCME
function M.GetState (name)
	local state = State[name]

	if state == nil then
		local set = assert(Sets[name], "Set not found")
		local make = set._state

		if make then
			Work = Work or {}
			Work.name, set._state = name

			make(Work)

			state, Work.result = Work.result or false
		else
			state = {}
		end
	end

	State[name] = state

	return state
end

local function AuxFindName (instance)
	local mt = getmetatable(instance)

	for name, set in pairs(Sets) do
		if rawequal(set, mt) then
			return _GetState_(name)
		end
	end
end

--- DOCME
function M.GetNameFromInstance (instance)
	return (AuxFindName(instance)) -- return nil if missing
end

--- DOCME
function M.GetStateFromInstance (instance)
	local name, state = AuxFindName(instance)

	if name ~= nil then
		state = _GetState_(name)
	end

	return state
end

local Reserved = { _before = true, _instead = true, _list = true, _name = true, _prototype = true }

local function MergePrototype (def, proto)
	for k, v in pairs(proto) do
		if k == "_list" and def._list then
			MergePrototype(def._list, v) -- will both be tables without own _list member
		elseif def[k] == nil then -- not defined in new type, including not extending anything in prototype
			def[k] = v
		end
	end
end

local function PrototypeEntry (proto, name)
	local list = proto._list
	local entry = list and list[name] or proto[name] -- n.b. fallthrough when list[name] nil

	return adaptive.IterArray(entry)
end

local function AddFunctionAfterProtoEntry (def, name, func, proto)
	local arr = def[name]

	if not arr then -- prototype calls not already merged by "before" logic?
		for _, ev in PrototypeEntry(proto, name) do
			arr = adaptive.Append(arr, ev)
		end
	end

	def[name] = adaptive.Append(arr, func)
end

local function AddFunctionBeforeProtoEntry (def, name, func, proto)
	local arr = adaptive.Append(nil, func)

	for _, ev in PrototypeEntry(proto, name) do
		arr = adaptive.Append(arr, ev)
	end

	def[name] = arr
end

local function AddFunctionDirectly (def, name, func)
	def[name] = func
end

local function WrapCallLists (def)
	local list

	for k, v in pairs(def) do
		if type(v) == "table" then
			list = list or {} -- only create if needed

			local function wrapped (event)
				for i = 1, #v do
					v[i](event)
				end
			end

			wrapped[k], def[k] = wrapped
		end
	end

	def._list = list
end

local function AddNewFunctions (def, params, add, proto)
	for k, v in pairs(params) do
		if not Reserved[k] then
			add(def, k, v, proto)
		end
	end

	WrapCallLists(def)
end

--- DOCME
-- @ptable params
-- @treturn table S
-- @return N
function M.New (params)
	assert(type(params) == "table", "Invalid params")

	local name = params._name

	assert(name ~= nil and name == name, "Invalid name")
	assert(not Sets[name], "Name already in use")

	local before, instead, pname, def = params._before, params._instead, params._prototype, {}

	if pname == nil then
		assert(not before, "Prototype must be available for `before` calls")
		assert(not instead, "Prototype must be available for `instead` calls")

		AddNewFunctions(def, params, AddFunctionDirectly)
	else
		local proto = assert(Sets[pname], "Prototype not found")

		if instead then
			assert(not instead._state, "Instead list may not contain `state` call")

			for k, v in pairs(instead) do
				assert(not (before and before[k] ~= nil), "Entry in `instead` also in `before`")
				assert(params[k] ~= nil, "Entry in `instead` also in main list")

				def[k] = v
			end
		end

		if before then
			assert(not before._state, "Before list may not contain `state` call")

			for k, v in pairs(before) do
				AddFunctionBeforeProtoEntry(def, k, v, proto)
			end
		end

		AddNewFunctions(def, params, AddFunctionAfterProtoEntry, proto)
		MergePrototype(def, proto)
	end

	Sets[name] = def -- add provisionally for GetState()...

	local init = def._init

	if init then
		local ok, err = pcall(init, name)

		if not ok then
			Sets[name] = nil -- ...but remove if something went wrong

			error(err)
		end
	end

	return def, name
end

_GetState_ = M.GetState

return M