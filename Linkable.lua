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
local setmetatable = setmetatable

-- Modules --
local function_set = require("s3_editor.FunctionSet")

-- ^^ TODO: better name? e.g. method bundle or something?

--
--
--

-- Iterator over a list of strings (tags or sublinks)
local IterStrList = iterator_utils.InstancedAutocacher(function()
	local str_list = {}

	-- Body --
	return function(_, i)
		return i + 1, str_list[i + 1]
	end,

	-- Done --
	function(_, i)
		return str_list[i + 1] == nil
	end,

	-- Setup --
	function(T, enum, name_, as_set, filter)
		-- Build up the list of strings, accommodating the form of the source.
		local count = 0

		if as_set then
			for base in adaptive.IterSet(name_) do
				count = enum(T, str_list, base, count, filter)
			end
		else
			for _, base in adaptive.IterArray(name_) do
				count = enum(T, str_list, base, count, filter)
			end
		end

		-- Enumeration will overwrite the old elements, but if the previous iteration was
		-- longer than this one, the list will still contain leftover elements at the tail
		-- end, so trim the list as needed. Remove any duplicates to get the final list.
		for i = #str_list, count + 1, -1 do
			str_list[i] = nil
		end

		array_funcs.RemoveDups(str_list)

		return nil, 0
	end
end)

-- Tags class definition --
--return class.Define(function(Tags)

local Type = {}

Type.__index = Type

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

local Node = {}

Node.__index = Node

--- Getter.
-- @treturn string Name.
function Node:GetName ()
	return self[_name]
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
		-- Sublink class definition --
		local SublinkClass = class.Define(function(Sublink)


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
		end)
			
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

-- Type:Iter (...)
--  IterTemplates (...)
--  IterNonTemplates (...)

-- M.EnumNamesGeneratedFrom (template, list) -- "instances"
-- M.EnumNamesNotGeneratedFrom (template, list) -- "no_instances"
-- M.NewType ({ methods, before, instead }, { export_nodes }, { import_nodes })
-- M.ReplaceGeneratedName (list, name) -- need type?
-- M.ReplaceNames...
-- M.RemoveGeneratedName (...) -- ????
-- M.GenerateName (list, template)

	--- DOCME
	-- @string name
	-- @string sub
	-- @treturn ?|string|nil X
	function Tags:Instantiate (name, sub)
		if IsTemplate(sub) then
			local template, _, ilist = FindSublink(self, name, sub)
			local id = (self.counters[sub] or 0) + 1
			local instance = ("%s|%i|"):format(sub:sub(1, -2), id)

			ilist[instance], self.counters[sub] = class.Clone(template, instance), id

			return instance
		else
			return nil
		end
	end

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

local Node = {}

Node.__index = Node

---
-- @ptable params
-- @treturn boolean X
function Node:CanLinkTo (params)
	-- already linked?
	-- !!!
end

---
-- @return Name.
function Node:GetName ()
	return self.m_name
end
-- ^^ TODO: is this important enough to keep, in light of the redundancy and imposed structure?

--[[
CanLink (id1, name1, pred1, id2, name2, pred2, linker)
	
end
]]

local function AddNode (NG, name, key, what, params)
	local node, list = {}, NG[name] or { m_name = name }

	if type(params) == "table" then
		--
	end

	NG[name], list[key] = list, setmetatable(node, Node)
end

local NodeGraph = {}

NodeGraph.__index = NodeGraph

function NodeGraph:AddExportNode (name, what, params)
	AddNode(self, name, "m_export_nodes", what, params)
end

function NodeGraph:AddImportNode (name, what, params)
	AddNode(self, name, "m_import_nodes", what, params)
end

function_set.New{
    _name = "Linkable",

    _state = function(event)
		event.result = setmetatable({}, NodeGraph)
    end,

    -- _init = ? (Add{Ex|Im}portNode, ...)

    -- default can_link (mostly just hooking up types, with or without 1-item limit)
		-- can_link (node, other, name, oname[, linker]) also ids
			-- ids needed e.g. for 1-item limit (check link count) or "link to any when empty, else compat"
		-- result = ...
			-- else: reason, is_contradiction
	-- ^^ if doing this with components, try to make cases that don't proliferate tables
		-- so maybe ask for interfaces? e.g. for uint -> int -> number
		-- components such as: boolean, event, etc.; is / is not limited to 1
		-- take id, etc. for "any" case, where there is sometimes flexibility
	-- ^^ also of course is node-level stuff
    -- default build, load, save (not sure how safe this is, unless hinted in node info)
    -- default prep_link... (use streamlined version of pubsub_utils stuff)
		-- result = true if resolved...
    -- default verify... (give hints in node info?)
}

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