--- Logic associated with listbox-based views. These are similar to the views as described in
-- @{s3_editor.GridViews}, but do not define **GetChoices**, **GetGrid**, or **GetTiles** methods.

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
local type = type

-- Modules --
local button = require("corona_ui.widgets.button")
local common = require("s3_editor.Common")
local editor_strings = require("config.EditorStrings")
local layout = require("corona_ui.utils.layout")
local match_slot_id = require("tektite_core.array.match_slot_id")
local strings = require("tektite_core.var.strings")
local table_view_patterns = require("corona_ui.patterns.table_view")

-- Corona globals --
local timer = timer
local transition = transition

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

local FadeParams = { time = 250 }

local function Fade (list, edit, delete, alpha)
	if list:Count() == 1 - alpha then -- n either 0 or 1
		FadeParams.alpha = alpha

		transition.to(delete, FadeParams)
		transition.to(edit, FadeParams)
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
	local list, values, watch_name, vfunc

	if type(vtype) == "function" then
		vfunc = vtype
	end

	--
	local ListView = {}

	--- DOCME
	function ListView:AddEntry (key, itype)
		local akey

		if itype then
			vtype, akey = itype, key
		elseif vfunc then
			vtype = vfunc()
		else
			akey = key
		end

		if vtype then
			akey = akey or vtype .. key

			values[akey] = dialog_wrapper("new_values", vtype, key)

			Fade(list, list.m_edit, list.m_delete, 1)

			local index = list:Append(akey)
			local tag = dialog_wrapper("get_tag", vtype)

			if tag then
				local entry = list:GetRect(index)

				common.BindRepAndValuesWithTag(entry, values[akey], tag, dialog_wrapper)
			end

			return values[akey]
		end

		return false
	end

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
	function ListView:Load (group, top, left, help_context)
		--
		list, values = table_view_patterns.Listbox(group, {
			width = "30%", height = "50%", text_rect_height = "6%", text_size = "3.25%",

			--
			get_text = function(key)
				return values[key].name
			end
		}), {}

		layout.LeftAlignWith(list, left)
		layout.PutBelow(list, top)

		--
		local using = match_slot_id.Wrap{}
		local new = button.Button_XY(group, 0, 0, "13.75%", "8.33%", function()
			if vfunc then
				vtype = vfunc()
			end

			if self:AddEntry(GetSuffix(list, using, vtype)) then
				common.Dirty()
			end
		end, "New")

		layout.LeftAlignWith(new, list)
		layout.PutBelow(new, list, "2.1%")

		--
		local delete = button.Button_XY(group, 0, new.y, new.width, new.height, function()
			local index = list:FindSelection()

			if index then
				local entry, key = list:GetRect(index), list:GetData(index)

				Fade(list, list.m_edit, list.m_delete, 0)

				list:Delete(index)

				dialog_wrapper("close")

				common.BindRepAndValues(entry, nil)
				common.Dirty()

				values[key] = nil
			end
		end, "Delete")

		layout.PutRightOf(delete, new, "1.25%")

		--
		local edit = button.Button_XY(group, 0, new.y, new.width, new.height, function()
			local index = list:FindSelection()

			if index then
				local key = list:GetData(index)

				if not dialog_wrapper("is_bound", values[key]) then
					dialog_wrapper("close")
					dialog_wrapper("edit", values[key], group, key)
				end
			end
		end, "Edit")

		list.m_edit, list.m_delete, delete.alpha, edit.alpha = edit, delete, 0, 0

		layout.PutRightOf(edit, delete, "1.25%")

		help_context:Add(delete, editor_strings("list_view_delete"))
		help_context:Add(edit, editor_strings("list_view_edit"))
		help_context:Add(new, editor_strings("list_view_new"))

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