--- Logic associated with listbox-based views. These are similar to the views as described in
-- @{s3_editor.GridViews}, but do not define **GetCurrent**, **GetGrid**, or **GetTiles** methods.

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
local tonumber = tonumber

-- Modules --
local button = require("corona_ui.widgets.button")
local common = require("s3_editor.Common")
local layout = require("corona_ui.utils.layout")
local match_slot_id = require("tektite_core.array.match_slot_id")
local strings = require("tektite_core.var.strings")
local table_view_patterns = require("corona_ui.patterns.table_view")

-- Exports --
local M = {}

--
local function GetName (using, prefix)
	using("begin_generation")

	local items = using("get_array")
	local n = #items

	for i = 1, n do
		local begins, suffix = strings.BeginsWith_AnyCase(items[i].name, prefix, true)
		local index = begins and tonumber(suffix)

		if index then
			using("mark", index)
		end
	end

	for i = 1, n do
		if not using("check", i) then
			return prefix .. i
		end
	end

	return prefix .. (n + 1)
end

--- DOCME
function M.EditErase (dialog_wrapper, action, vtype, top, left)
	local list, values

	local text = display.newText(Group, str, 0, 0, native.systemFont, 24)

--	return list, items, layout.Below(new)

	--
	local ListView = {}

	--- DOCME
	function ListView:Enter ()
		--
	end

	--- DOCME
	function ListView:Exit ()
		dialog_wrapper("close")
	end

	--- DOCME
	function ListView:GetListbox ()
		return list
	end

	--- DOCME
	function ListView:GetValues ()
		return values
	end

	--- DOCME
	function ListView:Load (group, prefix, title)
		values = {}



		local using, items = match_slot_id.Wrap{}
		local list = table_view_patterns.Listbox(group, {
			width = "30%", height = "15%",

			--
			press = function(event)
				action("update", using, event.index)
			end
		})

--	layout.PutRightOf(text, 125)
--	layout.PutBelow(text, top)
--	layout.LeftAlignWith(list, text)
--	layout.PutBelow(list, text)
--	common_ui.Frame(list, r, g, b)

		local new = button.Button_XY(group, 0, 0, 110, 40, function()
			action("new", using, list)
--[[
			if tile then
				common.GetLinks():RemoveTag(tile)
			end
			-- ^^^ Listbox item

			values[key] = dialog_wrapper("new_values", vtype, key)
			-- ^^ Should just put it in the listbox

			--
			local tag = dialog_wrapper("get_tag", vtype)

			if tag then
				common.BindRepAndValues(tiles[key], values[key])
				common.GetLinks():SetTag(tiles[key], tag)
			end

			common.Dirty()
]]
		end, "New")

		layout.LeftAlignWith(new, list)
		layout.PutBelow(new, list, 10)

		local delete = button.Button_XY(group, 0, new.y, new.width, new.height, function()
			local index = list:FindSelection()

			if index then
				remove(items, index)
				action("delete", using, list, index)
			end
--[[
			if tile then
				tile:removeSelf() -- "tile" = listbox item

				common.BindRepAndValues(tile, nil)
				common.Dirty()
			end

			values[key], tiles[key] = nil
]]
		end, "Delete")

		layout.PutRightOf(delete, new, 10)


--[[
EDIT:

			if cur then
				dialog_wrapper("edit", cur, tabs.parent, key, tile)
			else
				dialog_wrapper("close")
			end
]]

--[[
		--
		local choices = { "Paint", "Edit", "Erase" }

		tabs = M.AddTabs(group, choices, function(label)
			return function()
				option = label

				if label ~= "Edit" then
					dialog_wrapper("close")
				end

				return true
			end
		end, 300)
]]

		--
		help.AddHelp(prefix, { current = current, tabs = tabs })
	end

	--- DOCME
	function ListView:Unload ()
		list:removeSelf()

		list, values = nil
	end

	return ListView
end

-- Export the module.
return M