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

-- Corona globals --
local timer = timer

-- Exports --
local M = {}

--
local function AuxGetSuffix (str, _, using, prefix)
	local begins, suffix = strings.BeginsWith_AnyCase(str, prefix, true)
	local index = begins and tonumber(suffix)

	if index then
		using("mark", index)
	end
end

--
local function GetSuffix (list, using, prefix)
	using("begin_generation")

	list:ForEach(AuxGetSuffix, using, prefix)

	local n = list:GetCount()

	for i = 1, n do
		if not using("check", i) then
			return i
		end
	end

	return n + 1
end

--- DOCME
function M.EditErase (dialog_wrapper, vtype)
	local list, values, watch_name

	--
	local ListView = {}

	--- DOCME
	function ListView:Enter ()
		timer.resume(watch_name)
	end

	--- DOCME
	function ListView:Exit ()
		dialog_wrapper("close")

		timer.pause(watch_name)
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
	function ListView:Load (group, prefix, top, left)
		--
		list, values = table_view_patterns.Listbox(group, {
			width = "30%", height = "15%",

			--
			get_text = function(key)
				return values[key].name
			end
		}), {}

		layout.LeftAlignWith(list, left)
		layout.PutBelow(list, top)

		--
		local using = match_slot_id.Wrap{}
		local new = button.Button_XY(group, 0, 0, 110, 40, function()
			local key = GetSuffix(list, using, prefix)

			values[key] = dialog_wrapper("new_values", vtype, key)

			local index = list:Append(key)
			local tag = dialog_wrapper("get_tag", vtype)

			if tag then
				local entry = list:GetRect(index)

				common.BindRepAndValues(entry, values[key])
				common.GetLinks():SetTag(entry, tag)
			end

			common.Dirty()
		end, "New")

		layout.LeftAlignWith(new, list)
		layout.PutBelow(new, list, 10)

		--
		local delete = button.Button_XY(group, 0, new.y, new.width, new.height, function()
			local index = list:FindSelection()

			if index then
				local entry, key = list:GetRect(index), list:GetData(index)

				list:Delete(index)

				dialog_wrapper("close")

				common.BindRepAndValues(entry, nil)
				common.Dirty()

				values[key] = nil
			end
		end, "Delete")

		layout.PutRightOf(delete, new, 10)

		--
		local edit = button.Button_XY(group, 0, new.y, new.width, new.height, function()
			local index = list:FindSelection()

			if index then
				local key = list:GetData(index)

				if not dialog_wrapper("is_bound", values[key]) then
					dialog_wrapper("close")
					dialog_wrapper("edit", values[key], group, key, list:GetRect(index))
				end
			end
		end, "Edit")

		layout.PutRightOf(edit, delete, 10)

		--
		watch_name = timer.performWithDelay(150, function()
			local index = list:FindSelection()

			if dialog_wrapper("is_bound", values[list:GetData(index)]) then
				list:Update(index)
			end
		end, 0)
		timer.pause(watch_name)

		return list, layout.Below(new)
	end

	--- DOCME
	function ListView:Unload ()
		list:removeSelf()

		timer.cancel(watch_name)

		list, values, watch_name = nil
	end

	return ListView
end

-- Export the module.
return M