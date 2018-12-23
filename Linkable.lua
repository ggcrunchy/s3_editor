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
local rawequal = rawequal
local setmetatable = setmetatable

-- Modules --
local function_set = require("s3_editor.FunctionSet")
local node_pattern = require("s3_editor.NodePattern")

-- Exports --
local M = {}

--
--
--

-- M.EnumNamesGeneratedFrom (template, list) -- "instances"
-- M.EnumNamesNotGeneratedFrom (template, list) -- "no_instances"
-- M.ReplaceGeneratedName (list, name) -- need type?
-- M.ReplaceNames...

--
--
--

local Info = {}

Info.__index = Info

-- flat array of commands
-- list of already-added nodes
-- current cluster
-- 

local Work

local GetArgs = {}

local Block = {}

function Info:BlockNode (name)
	local block_linked, top = self.m_block_linked or {}, #Work

	assert(not block_linked[name], "Block already linked")

	self.m_block_linked, block_linked[name] = block_linked, true
	Work[#Work + 1] = Block
	Work[#Work + 1] = name

	return top + 1
end

function GetArgs.block (work, pos)
	return work[pos + 1]
end

local Nil = {}

local function MaybeNil (arg)
	return arg == nil and Nil or arg
end

local function Decode (arg)
	if arg ~= Nil then
		return arg
	else
		return nil
	end
end

function Info:AddNode (name, what, text)
	local added, top = self.m_added, #Work

	assert(not added[name], "Already added")
	assert(self.m_nodes:HasNode(name), "Invalid node")

	added[name] = true
	Work[#Work + 1] = name
	Work[#Work + 1] = MaybeNil(what)
	Work[#Work + 1] = MaybeNil(text)

	return top + 1
end

function GetArgs.node (work, pos)
	return work[pos], Decode(work[pos + 1]), Decode(work[pos + 2])
end

local String = {}

String.__index = String

function Info:AddString (text, side)
	assert(text ~= nil, "Invalid text")

	local str = self.m_string

	if not str then
		str = setmetatable({}, String)
		self.m_string = str
	end

	local top = #Work

	Work[#Work + 1] = String
	Work[#Work + 1] = text
	Work[#Work + 1] = side or "none"
	Work[#Work + 1] = Nil -- color...
	Work[#Work + 1] = Nil -- ...and font

	str.m_last = #Work

	return top + 1--str
end

function GetArgs.string (work, pos)
	return work[pos + 1], work[pos + 2], Decode(work[pos + 3]), Decode(work[pos + 4])
end

function String:SetColor (color)
	self[self.m_last - 1] = MaybeNil(color)
end

function String:SetFont (font)
	self[self.m_last] = MaybeNil(font)
end

local Cluster = {}

Cluster.__index = Cluster

function Info:BeginCluster ()
	local cluster = self.m_cluster

	if not cluster then
		cluster = setmetatable({}, Cluster)
		self.m_cluster = cluster
	elseif cluster.m_first then
		cluster:Close()
	end

	local top = #Work

	Work[#Work + 1] = Cluster
	Work[#Work + 1] = Nil -- color...
--	Work[#Work + 1] = Nil -- ...and final position

	cluster.m_last = #Work

	return top + 1--cluster
end

function GetArgs.begin_cluster (work, pos)
	return Decode(work[pos + 1])
end

function Cluster:Close () -- probably not relevant in first pass
	assert(self.m_last, "Cluster already closed")

	Work[self.m_last], self.m_last = #Work -- final position belonging to this cluster
end

function Cluster:SetColor (color)
	Work[self.m_last - 1] = MaybeNil(color)
end

local End = {}

function Info:EndCluster ()
	Work[#Work + 1] = End

	return #Work--End
end

local function DefGetArgs () end

local function Visit (block, work, ops, arg)
	for i = 1, #block do
		local pos, what = block[i]
		local first = work[pos]

		if rawequal(first, String) then
			what = "string"
		elseif rawequal(first, Cluster) then
			what = "begin_cluster"
		elseif rawequal(first, End) then
			what = "end_cluster"
		elseif rawequal(first, Block) then
			what = "block"
		else
			what = "node"
		end

		local op = ops[what]

		if op then
			op(arg, (GetArgs[what] or DefGetArgs)(work, pos))
		end
	end
end

local InCluster

local Validate = {
	block = function(blocks, name)
		assert(blocks and blocks[name], "Invalid block name")
	end,

	begin_cluster = function()
		assert(not InCluster, "Another cluster is still open")

		InCluster = true
	end,

	end_cluster = function()
		assert(InCluster, "No cluster open")

		InCluster = false
	end
}

local function ProcessNodeInfo (assign_node_info, node_pattern)
	Work, InCluster = {}, false

	local work, info = Work, setmetatable({ m_added = {}, m_nodes = node_pattern }, Info)
	local primary, blocks = assign_node_info(info)

	Visit(primary, Work, Validate, blocks)

	if blocks then
		for _, block in pairs(blocks) do
			Visit(block, Work, Validate, blocks)
		end
	end

	Work = nil

	return work, primary, blocks
end

local function UseNodeInfo (--[[err....]])
	-- uh...
--	Visit(MyOps)
	-- this probably is an event of some sort
end

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

	_init = function(name, def)
		local init_nodes = def.init_nodes

		if init_nodes then
			local state = function_set.GetState(name)
			local nodes = node_pattern.New(EnvID)

			init_nodes(nodes)

			state.nodes = nodes

			local assign_node_info = def.assign_node_info

			if assign_node_info then
				state.work, state.primary, state.blocks = ProcessNodeInfo(assign_node_info, nodes)
				-- do something with info
				-- do this now? (would error early if broken...)
					-- or on demand? (...but would get expensive if loading many object types)
			end
		end

		def.assign_node_info, def.init_nodes = nil
	end

	-- "decoration for nodes", e.g. the "link info" and "grouping" from before
	-- possibly different: remaps for build_link, see below
		-- if not string would get ugly!
	-- variable types and defaults
		-- also ordering
	-- probably also a text lookup section, to allow for localization
	-- might make sense to put generated names and labels here too?
		-- sounds like it might entail more complex fixup than now?
	-- dependencies, e.g. remove X if Y not linked, or similar for verification

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