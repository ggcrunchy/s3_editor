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
local next = next
local pairs = pairs
local rawget = rawget
local setmetatable = setmetatable
local tostring = tostring
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local component = require("tektite_core.component")
local meta = require("tektite_core.table.meta")

-- Exports --
local M = {}

--
--
--







local PrimaryInterfaceOf = meta.Weak("k")

--- DOCME
function M.ImplementsValue (event)
	return component.ImplementedByObject(event.target, Value)
end

local function Mangle (what, which)
	return "IFX:" .. which .. ":" .. type(what) .. ":" .. tostring(what) -- reasonably unique name
end

local function GetInterfaces (NG, what, which)
	local ifx_list = NG.m_interface_lists[which]
	local interfaces = ifx_list and ifx_list[what]

	if type(interfaces) == "number" then -- index?
		return NG.m_mangled[interfaces]
	else
		local index, list = #NG.m_mangled + 1

		if interfaces then
			for i = 1, #interfaces do
				list = adaptive.Append(list, Mangle(interfaces[i]))
			end
		else
			list = adaptive.Append(nil, Mangle(what))
		end

		NG.m_mangled[index], ifx_list[what] = list, index

		return list
	end
end

local Modifiers = {
	["-"] = "limit", ["+"] = "limit",
	["="] = "strict",
	["!"] = "wildcard", ["?"] = "wildcard"
}

local function ExtractModifiers (what)
	local mods

	for _ = 1, #what do
		local last = what:sub(-1)
		local modifier = Modifiers[last]

		if modifier then
			assert(not (mods and mods[modifier]) or mods[modifier] == last, "Conflicting modifiers")

			mods = mods or {}
			mods[modifier] = last
		else
			break
		end

		what = what:sub(1, -2)
	end

	assert(#what > 0, "Empty rule name")

	return what, mods
end

local Wildcard = {}

local function ImplementsInterface (ifx, strict)
	return function(event)
		if component.ImplementedByObject(event.target, ifx) then
			return true
		else
			return not strict and component.ImplementedByObject(event.target, Wildcard)
		end
	end
end

local function DefFineMatch () return true end

local function HasNoLinks (event)
	return not event.linker:HasLinks(event.from_id, event.from_name)
end

local function SynthesizeRule (limit, mods, oifx_primary)
	local coarse = ImplementsInterface(oifx_primary, mods and mods.strict)
	local fine = limit and HasNoLinks or DefFineMatch

	return function(event)
		if coarse(event) then
			if fine(event) then
				return true
			else
				return false, "Single-link node already bound" -- n.b. currently only possible failure
			end
		else
			return false, "Incompatible type"
		end
	end
end

local function SynthesizeWildcardRule (limit, mods, filter)
	if limit then
		return function(event)
			if HasNoLinks(event) then
				if filter(event) then
					return true
				else
					return false, "Type not covered by wildcard"
				end
			else
				return false, "Single-link node already bound"
			end
		end
	elseif mods.wildcard == "?" then
		local operative_ifx

		return function(event)
			if filter(event) then
				if HasNoLinks(event) then
					-- speculatively bind operative_ifx
					return true
				elseif component.ImplementedByObject(event.target, operative_ifx) then
					return true
				else
					return false, "Type incompatible with operative interface"
				end
			else
				return false, "Type not covered by wildcard"
			end
		end
	else
		return function(event)
			if filter(event) then
				return true
			else
				return false, "Type not covered by wildcard"
			end
		end
	end
end

local function IgnoredByWildcards (what, mods)
	return what == "func" or (mods and mods.strict) -- at the moment wildcards only accept values
end

local function ResolveLimit (what, which, mods)
	if what == "func" -- import an event that calls func, or call func that exports event
	or which == "exports" then
		return (mods and mods.limit) == "-"	-- usually fine to export value to multiple recipients,
												-- to broadcast an event,
												-- or to make a func callable from disparate events
	else
		return (mods and mods.limit) ~= "+" -- usually only makes sense to import one value
	end
end

local function MakeRule (NG, what, which)
	local mods

	if type(what) == "string" then
		what, mods = ExtractModifiers(what)
	end

	local limit = ResolveLimit(what, which, mods)

	if mods and mods.wildcard then
		local wpreds = assert(NG.m_wildcard_predicates, "No wildcard predicates defined")
		local filter = assert(wpreds[what], "Invalid wildcard predicate")

		return SynthesizeWildcardRule(limit, mods, filter), Wildcard
	else
		local other = which == "imports" and "exports" or "imports"
		local iter, state, index = adaptive.IterArray(GetInterfaces(NG, what, other))
		local _, oifx_primary = iter(state, index) -- iterate once to get primary interface
		local interfaces = GetInterfaces(what, which)

		if not IgnoredByWildcards(what, mods) then
			interfaces = adaptive.Append(interfaces, Value)
		end

		return SynthesizeRule(limit, mods, oifx_primary), interfaces
	end
end

local function GetRule (NG, what, which)
	if type(what) == "function" then -- already a rule, essentially
		return what
	else
		local rule_list = NG.m_rules[which]
		local rule = rule_list[what]

		if not rule then
			local name, interfaces = {}

			rule, interfaces = MakeRule(NG, what, which)

			component.RegisterType{ name = name, interfaces = interfaces }
			component.AddToObject(rule, name)
			component.LockInObject(rule, name)

			rule_list[what] = rule
		end

		return rule
	end
end

local function AddNode (NG, name, key, what)
	local elist, ilist = NG.m_export_nodes, NG.m_import_nodes

	assert(not (elist and elist[name]), "Name already used in exports list")
	assert(not (ilist and ilist[name]), "Name already used in imports list")

	local list = NG[key] or {}

	NG[key], list[name] = GetRule(NG, what, key == "m_export_nodes" and "exports" or "imports")
end

local NodeGraph = {}

NodeGraph.__index = NodeGraph

--- DOCME
function NodeGraph:AddExportNode (name, what)
	AddNode(self, name, "m_export_nodes", what)
end

--- DOCME
function NodeGraph:AddImportNode (name, what)
	AddNode(self, name, "m_import_nodes", what)
end

local function IsTemplate (name)
	return type(name) == "string" and name:sub(-1) == "*"
end

--- DOCME
function NodeGraph:Generate (name)
	if IsTemplate(name) then
		local elist, ilist = self.m_export_nodes, self.m_import_nodes
		local rule = (elist and elist[name]) or (ilist and ilist[name])

		if rule then
			local counters = self.m_counters
			local id = (counters[name] or 0) + 1
			local gend = ("%s|%i|"):format(name:sub(1, -2), id)

			counters[name] = id

			return gend, rule
		end
	end

	return nil
end

local function AuxIterBoth (NG, name)
	local ilist = NG.m_import_nodes

	if not rawget(ilist, name) then -- nil or in export list?
		local k, v = next(NG.m_export_nodes, name)

		if k == nil then -- switch from export to import list?
			return next(ilist, nil)
		else
			return k, v
		end
	else
		return next(ilist, nil)
	end
end

local function DefIter () end

local function IterBoth (NG)
	local elist, ilist = NG.m_export_nodes, NG.m_import_nodes

	if elist and ilist then
		return AuxIterBoth, NG, nil
	elseif elist or ilist then
		return adaptive.IterSet(elist or ilist)
	else
		return DefIter
	end
end

--- DOCME
function NodeGraph:IterNodes (how)
	if how == "exports" or how == "imports" then
		return adaptive.IterSet(self[how == "exports" and "m_export_nodes" or "m_import_nodes"])
	else
		return IterBoth(self)
	end
end

--- DOCME
function NodeGraph:IterNonTemplateNodes (how)
	local list = {}

	for k, v in self:IterNodes(how) do
		if not IsTemplate(k) then
			list[k] = v
		end
	end

	return pairs(list)
end

--- DOCME
function NodeGraph:IterNonTemplateNodes (how)
	local list = {}

	for k, v in self:IterNodes(how) do
		if IsTemplate(k) then
			list[k] = v
		end
	end

	return pairs(list)
end

local function ListInterfaces (NG, key, ifx_lists)
	local list, out = ifx_lists[key]

	assert(list == nil or type(list) == "table", "Non-table interface list")

	for k, v in pairs(list) do
		out = out or {}
		out[k] = v
	end

	NG.m_interface_lists[key] = out
end

--- DOCME
function M.New (params)
	local graph = {
		m_counters = {}, m_interface_lists = {}, m_mangled = {},
		m_rules = { exports = {}, imports = {} }
	}

	if params ~= nil then
		assert(type(params) == "table", "Non-table params")

		local ifx_lists, wlist = params.interface_lists, params.wildcards

		assert(ifx_lists == nil or type(ifx_lists) == "table", "Non-table interface lists")
		assert(wlist == nil or type(wlist) == "table", "Non-table wildcard list")

		if ifx_lists then
			ListInterfaces(graph, "exports", ifx_lists)
			ListInterfaces(graph, "imports", ifx_lists)
		end

		if wlist ~= nil then
			local wpreds

			for k, v in pairs(wlist) do
				assert(type(k) == "string", "Non-string wildcard predicate name")
				assert(type(v) == "function", "Non-function wildcard predicate")

				wpreds = wpreds or {}
				wpreds[k] = v
			end

			graph.m_wildcard_predicates = wpreds
		end
	end

	return setmetatable(graph, NodeGraph)
end