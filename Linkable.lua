--- MIRMAL!

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
local function_set = require("s3_editor.FunctionSet")

-- Exports --
local M = {}

--
--
--

	-- Forward references --
	local GetTemplate, ReplaceSingleInstance

local function IsTemplate (name)
	return type(name) == "string" and name:sub(-1) == "*"
end

	-- Nothing to iterate
	local function NoOp () end

	-- Iterate pairs()-style, if the table exists
	local function Pairs (t)
		if t then
			return pairs(t)
		else
			return NoOp
		end
	end

	do
		--
		local function AuxHasSublink (T, name, sub)
			--
			local tag = T[_tags][name]
			local sub_links = tag.sub_links

			if sub_links then
				local instances = tag.instances
				local sublink = sub_links[sub] or (instances and instances[sub])

				if sublink then
					return sublink, sub_links, instances
				end
			end
		end

		-- --
		local Name1, Sub1, Sublink1, SublinksList1, InstancesList1
		local Name2, Sub2, Sublink2, SublinksList2, InstancesList2

		--
		local function FindSublink (T, name, sub)
			if name == Name1 and sub == Sub1 then
				return Sublink1, SublinksList1, InstancesList1
			elseif name == Name2 and sub == Sub2 then
				return Sublink2, SublinksList2, InstancesList2
			else
				local sublink, slist, ilist = AuxHasSublink(T, name, sub)

				Name1, Sub1, Sublink1, SublinksList1, InstancesList1 = name, sub, sublink, slist, ilist
				Name2, Sub2, Sublink2, SublinksList2, InstancesList2 = Name1, Sub1, Sublink1, SublinksList1, InstancesList1

				return sublink, slist, ilist
			end
		end

		--- DOCME
		function Tags:CanLink (name1, name2, object1, object2, sub1, sub2, arg)
			local is_cont, why = true

			if IsTemplate(sub1) then
				why = "Sublink #1 is a template: `" .. sub1 .. "`"
			elseif IsTemplate(sub2) then
				why = "Sublink #2 is a template: `" .. sub2 .. "`"
			else
				local so1 = FindSublink(self, name1, sub1)

				if so1 then
					local so2 = FindSublink(self, name2, sub2)

					if so2 then
						local passed = true

						for _, can_link in adaptive.IterArray(so1[_can_link]) do
							passed, why, is_cont = can_link(object1, object2, so1, so2, arg)

							if not passed then
								break
							end
						end

						if passed then
							return true
						end
					else
						why = "Missing sublink #2: `" .. (sub2 or "?") .. "`"
					end
				else
					why = "Missing sublink #1: `" .. (sub1 or "?") .. "`"
				end
			end

			return false, why or "", not not is_cont
		end
-- ^^ sort of used elsewhere
--- DOCME
function Type:GetTemplate (name)
	local pi, nodes = name:find("|"), self.m_nodes
	local template = (pi and nodes) and name:sub(1, pi - 1) .. "*"

	return nodes[template] and template
end

		--- Predicate.
		-- @param name
		-- @string sub
		-- @param what
		-- @treturn boolean X
		function Tags:ImplementedBySublink (name, sub, what)
			local sub_link = FindSublink(self, name, sub)

			return sub_link ~= nil and sub_link:Implements(what)
		end
-- ^^ one use in link.lua

	end

	do

			--- Predicate.
			-- @param what
			-- @treturn boolean X
			function Sublink:Implements (what)
				return adaptive.InSet((self[_template] or self)[_interfaces], what)
			end
-- ^^ used here...
			--- Class cloner.
			-- @string name Instance name.
			function Sublink:__clone (S, name)
				for _, can_link in adaptive.IterArray(S[_can_link]) do
					self[_can_link] = adaptive.Append(self[_can_link], can_link)
				end

				for _, link_to in adaptive.IterArray(S[_link_to]) do
					self[_link_to] = adaptive.Append(self[_link_to], link_to)
				end

				self[_name], self[_template] = name, S
			end
	--	end)
			
		--
		local function AddInterface (sub, what)
			adaptive.AddToSet_Member(sub, _interfaces, what)
		end

		--
		local function CanLinkTo (_, _, sub, other_sub)
			local link_to = sub[_link_to]

			for _, what in adaptive.IterArray(link_to) do
				if other_sub:Implements(what) then
					return true
				end
			end

			local list, names

			for _, what in adaptive.IterArray(link_to) do
				names = adaptive.Append(names, what)
			end

			if type(names) == "table" then
				list = "`" .. concat(names, "` or `") .. "`"
			else
				list = "`" .. names .. "`" -- known to contain at least one
			end

			return false, "Expected " .. list, true
		end

		--- DOCME
		-- @param name
		-- @param what
		function Tags:ImplyInterface (name, what)
			adaptive.AddToSet_Member(self[_implies], name, what)
		end
-- used for type reciprocity...
		--
		local function AddImplementor (T, name, what)
			local implemented_by = T[_implemented_by]

			for impl_by in adaptive.IterSet(implemented_by[what]) do
				--[[
				if Is(T, name, impl_by) then
					return
				end
				]]
			end

			adaptive.AddToSet_Member(implemented_by, what, name)
		end

		--- DOCME
		-- @string name
		-- @ptable[opt] options
		function Tags:New (name, options)
			local tags = self[_tags]

			assert(not tags[name], "Tag already exists")

			local tag, new = {}

			if options then
				-- We track the tag's parent and child tag names, so that these may be iterated.
				-- The parents are only assigned at tag creation, so we can safely put these at
				-- the beginning of the tag's info array; whereas child tags may be added over
				-- time. By making note of how many parents there were, however, we can append
				-- the children to the same array: namely, the new tag name itself is here added
				-- to each of its parents.
				for _, pname in ipairs(options) do
					local ptag = assert(tags[pname], "Invalid parent")

					assert(ptag[#ptag] ~= name, "Duplicate parent")

					ptag[#ptag + 1], tag[#tag + 1] = name, pname
				end

				-- Add any sublinks.
				local sub_links, implies = options.sub_links, self[_implies]

				if sub_links then
					local new = {}

					for name, sub in pairs(sub_links) do
						local stype, obj, link_to = type(sub), SublinkClass(name)

						--
						if type(name) == "string" then
							assert(name:find("|") == nil, "Pipes are reserved for instanced templates")
							assert(name:find(":") == nil, "Colons are reserved for compound IDs")

							if name:sub(-1) == "*" and not tag.instances then
								self.counters, tag.instances = self.counters or {}, {}
							end
						end

						--
						if stype == "table" then
							for _, v in ipairs(sub) do
								AddInterface(obj, v)
							end

							--
							link_to = sub.link_to

						--
						elseif sub then
							link_to = sub
						end
						
						--
						local found_string

						for _, what in adaptive.IterArray(link_to) do
							local wtype = type(what)

							if wtype == "string" then
								if not found_string then
									obj[_can_link], found_string = adaptive.Append(obj[_can_link], CanLinkTo), true
								end

								obj[_link_to] = adaptive.Append(obj[_link_to], what)

								--
								for interface in adaptive.IterSet(implies[what]) do
									AddInterface(obj, interface)
								end

							--
							elseif wtype == "function" then
								obj[_can_link] = adaptive.Append(obj[_can_link], what)
							end
						end

						--
						new[name] = obj
					end

					tag.sub_links = new
				end

				--
				for _, sub in Pairs(new) do
					for what in adaptive.IterSet(sub[_interfaces]) do
						AddImplementor(self, name, what)
					end
				end
			end

			--
			tags[name], tag.nparents = tag, #(options or "")
		end
	end

	do
		--
		local Template

		local function GeneratedFrom (name)
			local where = name:find("|")

			return where and name:sub(where - 1) == Template
		end

		--
		local Filters = {
			instances = function(name)
				return name:sub(-1) == "|"
			end,

			no_instances = function(name)
				return name:sub(-1) ~= "|"
			end,

			no_templates = function(name)
				return name:sub(-1) ~= "*"
			end,

			templates = function(name)
				return name:sub(-1) == "*"
			end
		}

		--
		local function EnumSublinks (T, str_list, name, count, filter)
			--
			local tag, was = T[_tags][name], count

			for _, v in Pairs(tag.sub_links) do
				str_list[count + 1], count = v:GetName(), count + 1
			end

			for name in Pairs(tag.instances) do
				str_list[count + 1], count = name, count + 1
			end

			--
			if filter then
				for i = count, was + 1, -1 do
					if not filter(str_list[i]) then
						str_list[i] = str_list[count]
						count, str_list[count] = count - 1
					end
				end
			end

			return count
		end

		--- DOCME
		-- @string name
		-- @string[opt] filter
		-- @treturn iterator I
		function Tags:Sublinks (name, filter)
			if filter then
				if IsTemplate(filter) then
					filter, Template = GeneratedFrom, filter:sub(1, -2)
				else
					filter = Filters[filter]
				end
			end

			return IterStrList(self, EnumSublinks, name, false, filter)
		end
	end

	-- Bind references.
	GetTemplate, ReplaceSingleInstance = Tags.GetTemplate, Tags.ReplaceSingleInstance
--end)

-- M.EnumNamesGeneratedFrom (template, list) -- "instances"
-- M.EnumNamesNotGeneratedFrom (template, list) -- "no_instances"
-- M.ReplaceGeneratedName (list, name) -- need type?
-- M.ReplaceNames...
-- M.RemoveGeneratedName (...) -- ????

	--- DOCME
	-- @string name
	-- @string instance
	-- @treturn boolean X
	function Tags:Release (name, instance)
		local sublink, _, ilist = FindSublink(self, name, instance)

		if sublink then
			ilist[instance] = nil

			return true
		else
			return false
		end
	end

	--- DOCME
	function Tags:ReplaceInstances (tag, instances)
		local replacements = {}

		for k in Pairs(instances) do
			replacements[k] = ReplaceSingleInstance(self, tag, k)
		end

		return replacements
	end

	--- DOCME
	function Tags:ReplaceSingleInstance (tag, instance)
		local template = GetTemplate(self, tag, instance)

		return template and self:Instantiate(tag, template)
	end

--
--
--

--[[
CanLink (id1, name1, pred1, id2, name2, pred2, linker)
	
end
]]

local InterfaceLists = { exports = {}, imports = {} }

local MangledLists = {}

local function Mangle (what, which)
	return "IFX:" .. which .. ":" .. type(what) .. ":" .. tostring(what) -- reasonably unique name
end

local function GetInterfaces (what, which)
	local ifx_list = InterfaceLists[which]
	local interfaces = ifx_list[what]

	if type(interfaces) == "number" then -- index?
		return MangledLists[interfaces]
	else
		local index, list = #MangledLists + 1

		if not interfaces then
			list = adaptive.Append(nil, Mangle(what))
		else
			for i = 1, #interfaces do
				list = adaptive.Append(list, Mangle(interfaces[i]))
			end
		end

		MangledLists[index], ifx_list[what] = list, index

		return list
	end
end

local OptOut = {}

local function BasicLink (oifx_primary)
	return function(event)
		if component.ImplementedByObject(event.target, oifx_primary) then
			return true
		else
			return false, "Incompatible type"
		end
	end
end

local function SingleTargetLink (oifx_primary)
	return function(event)
		if component.ImplementedByObject(event.target, oifx_primary) then
			if not event.linker:HasLinks(event.from_id, event.from_name) then
				return true
			else
				return false, "Single-link node already bound"
			end
		else
			return false, "Incompatible type"
		end
	end
end

local Modifiers = { ["-"] = "limit", ["+"] = "limit", ["="] = "opt_out", ["!"] = "unconstrained" }

local function ExtractModifiers (what)
	local limit, mods

	for _ = 1, #what do
		local last = what:sub(-1)
		local modifier = Modifiers[last]

		if modifier == "limit" then
			assert(not limit or limit == last, "Conflicting limit modifiers")

			limit = last
		elseif modifier then
			mods = mods or {}
			mods[modifier] = true
		else
			break
		end

		what = what:sub(1, -2)
	end

	assert(#what > 0, "Empty rule name")

	return what, limit, mods
end

local function DefCanStillLink () return true end

local function SynthesizeRule (limit, wildcard, oifx_primary)
	local can_match, can_still_link = nil, DefCanStillLink

	if limit and wildcard then -- n.b. with limit wildcard forms are equivalent
		-- return SingleTargetWildcardLink(oifx_primary, any)
	elseif limit then
		return SingleTargetLink(oifx_primary)
	elseif wildcard then
		-- return UniformWildcardLink(oifx_primary, any)
	elseif wildcard == "!" then
		-- return MixtureWildcardLink(oifx_primary, any)
	else
		return BasicLink(oifx_primary)
	end
end
-- argh, realizing this is all wrong...
-- just need "any" (or predef'd alternatives) for 'what", where "any" just excludes "func"
-- then "!" would make wide open, else the restrictive version
-- two "any"s cannot link, even if restrictively resolved
-- what's a good opt-out sigil, then?
local function MakeRule (what, which)
	local limit, mods

	if type(what) == "string" then
		what, limit, mods = ExtractModifiers(what)
	end

	if what == "func" -- import an event that calls func, or call func that exports event
	or which == "exports" then
		limit = limit == "-"-- usually fine to export value to multiple recipients,
							-- to broadcast an event,
							-- or to make a func callable from disparate events
	else
		limit = limit ~= "+" -- usually only makes sense to import one value
	end

	local other = which == "imports" and "exports" or "imports"
	local iter, state, index = adaptive.IterArray(GetInterfaces(what, other))
	local _, oifx_primary = iter(state, index) -- iterate once to get primary interface
	local interfaces = GetInterfaces(what, which)

	if mods and mods.opt_out then
		interfaces = adaptive.Append(interfaces, OptOut)
	end

	return SynthesizeRule(limit, mods, oifx_primary), interfaces
end

local function ListInterfaces (what, which, ...)
	local list = InterfaceLists[which]

	assert(not list[what], "List already provided")

	list[what] = { ... }
end

--- DOCME
function M.ListExportInterfaces (what, ...)
	ListInterfaces(what, "exports", ...)
end

--- DOCME
function M.ListImportInterfaces (what, ...)
	ListInterfaces(what, "imports", ...)
end

local OpenKinds = { any = { blacklist = "func" } }

--- DOCME
function M.MakeOpenKind (params)
	assert(type(params) == "table", "Non-table params")

	local name = params.name

	assert(name ~= nil, "Missing name")
	assert(not OpenKinds[name], "Name already in use")

	local pwlist, blist, wlist = params.whitelist

	for what in adaptive.IterSet(params.blacklist) do
		assert(not adaptive.InSet(pwlist, what), "Entry in both blacklist and whitelist")

		blist = adaptive.AddToSet(blist, what)
	end

	for what in adaptive.IterSet(pwlist) do
		wlist = adaptive.AddToSet(wlist, what)
	end

	OpenKinds[name] = { blacklist = blist, whitelist = wlist }
end

local Rules = { exports = {}, imports = {} }

local function GetRule (what, which)
	if type(what) == "function" then -- already a rule, essentially
		return what
	else
		local rule_list = Rules[which]
		local rule = rule_list[what]

		if not rule then
			local name, interfaces = {}

			rule, interfaces = MakeRule(what, which)

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

	NG[key], list[name] = GetRule(what, key == "m_export_nodes" and "exports" or "imports")
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

function_set.New{
    _name = "Linkable",

    _state = function(event)
		local graph = setmetatable({}, NodeGraph)

		event.result, graph.m_counters = graph, {}
    end,

	build_link = function(entry, other, name, other_name)
		-- stuff from prep link helper, basically
			-- but can probably mostly streamline, accounting for "func" and generated names
		-- check for "is resolved" something or other, exit if set
		-- otherwise, set it ourself if successful
		-- locations might be defaulted but overrideable in Add*Node?
	end,

	post_build_link = function(...)
		-- clean anything up from build_link
		-- might not be anything in default version
	end,
    -- _init = ? (Add{Ex|Im}portNode, ...)

    -- default can_link (mostly just hooking up types, with or without 1-item limit)
		-- can_link (node, other, name, oname[, linker]) also ids
			-- ids needed e.g. for 1-item limit (check link count) or "link to any when empty, else compat"
		-- result = ...
			-- else: reason, is_contradiction

    -- default build, load, save (not sure how safe this is, unless hinted in node info)
    -- default verify... (give hints in node info?)
}

return M

-- derived by:
    -- Action
        -- etc.
    -- Dot
        -- etc.
    -- Enemy
        -- etc.
    -- EventBlock
        -- etc.
    -- Value
        -- etc.
    -- Other...

-- want something to allow this for individual methods of objects...
    -- just to reduce clutter
    -- glorified attachment
    -- would be nice to be able to make more "views" of object