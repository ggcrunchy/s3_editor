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
local pairs = pairs
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local function_set = require("s3_editor.FunctionSet")
local node_pattern = require("s3_editor.NodePattern")

-- Exports --
local M = {}

--
--
--

	-- Forward references --
	local GetTemplate, ReplaceSingleInstance

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

local EnvID = node_pattern.NewEnvironment{
	-- interface_lists = ..., e.g. uint exports [ uint, int, number ]
	wildcards = { value = node_pattern.ImplementsValue }
}

function_set.New{
    _name = "Linkable",

    _state = function(event)
		event.result = {
			nodes = node_pattern.New(EnvID),
			-- "decoration for nodes", e.g. the "link info" and "grouping" from before
			-- possibly different: remaps for build_link, see below
				-- if not string would get ugly!
			-- variable types and defaults
				-- also ordering
			-- probably also a text lookup section, to allow for localization
			-- might make sense to put generated names and labels here too?
				-- sounds like it might entail more complex fixup than now?
			-- dependencies, e.g. remove X if Y not linked, or similar for verification
		}
    end,

	build_link = function(event) -- entry, other, entry_name, other_name, linker, names, labels
		if event.result == nil then -- ignore if handled in "before"
		-- stuff from prep link helper, basically
			-- but can probably mostly streamline, accounting for "func" and generated names
		-- check for "is resolved" something or other, exit if set
		-- otherwise, set it ourself if successful
		-- locations might be defaulted but overrideable in Add*Node?
			-- into table for various things
			-- renamed key say as in switch
		end
	end,

	post_build_link = function(_)
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