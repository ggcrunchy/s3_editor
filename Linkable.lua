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
				-- info = prep
				-- info:Reset(nodes)
				-- assign_node_info(info)
				-- state.node_info = info:get_info()
				-- do something with info
				-- do this now?
					-- or on demand?
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