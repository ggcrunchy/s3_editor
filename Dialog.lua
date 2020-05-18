--- A dialog-type widget.

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
local augment = require("s3_editor.Augment")
local common = require("s3_editor.Common")
local dialog = require("solar2d_ui.widgets.dialog")
local table_funcs = require("tektite_core.table.funcs")

-- Solar2D globals --
local display = display

-- Cached module references --
local _Dialog_

-- Exports --
local M = {}

--
--
--

-- --
local Namespace = {}

--- DOCME
-- @pgroup group Group to which the dialog will be inserted.
-- @ptable options
--
-- **CONSIDER**: In EVERY case so far I've used _name_ = **true**...
function M.Dialog (group, options)
	--
	options = options and table_funcs.Copy(options) or {}

	options.augment = augment
	options.namespace = Namespace

	--
	local edialog = dialog.Dialog(group, options)

	edialog:addEventListener("update_object", common.Dirty)

	return edialog
end

-- Helper to populate defaults
local function GetDefaults (on_editor_event, type, key)
	local defs = { name = type .. " " .. key, type = type }

	on_editor_event(type, "enum_defs", defs)

	return defs
end

--- DOCME
-- @callable on_editor_event
-- @treturn function X
function M.DialogWrapper (on_editor_event)
	local dialog, dx, dy

	-- If we're closing a dialog (or switching to a different one), remember the
	-- current dialog's position, so that the next dialog can appear there.
	local function BeforeRemove ()
		dx, dy, dialog = dialog.x, dialog.y
	end

	return function(what, arg1, arg2, arg3)
		--
		if what == "get_dialog" then
			return dialog

		--
		elseif what == "get_editor_event" then
			return on_editor_event

		--
		-- arg1: Value type
		elseif what == "get_tag" then
			return common.GetTag(arg1, on_editor_event)

		--
		-- arg1: Value type
		-- arg2: Key
		elseif what == "new_values" then
			return GetDefaults(on_editor_event, arg1, arg2)

		--
		-- arg1: Values table
		elseif what == "is_bound" or what == "edit" then
			local is_bound = dialog and dialog:IsBoundToValues(arg1)

			if what == "is_bound" or is_bound then
				return is_bound
			end

		--
		-- arg1: Value type
		-- arg2: Info to populate
		elseif what == "get_link_info" then
			on_editor_event(arg1, "get_link_info", arg2)
		end

		--
		if (what == "close" or what == "edit") and dialog then
			dialog:RemoveSelf()
		end

		--
		-- arg1: Values to edit
		-- arg2: Group
		-- arg3: Key
		if what == "edit" then
			if arg1 then
				dialog = _Dialog_(arg2)

				dialog:BindDefaults(GetDefaults(on_editor_event, arg1.type, arg3))
				dialog:BindValues(arg1)

				on_editor_event(arg1.type, "enum_props", dialog)

				dialog:addEventListener("before_remove", BeforeRemove)

				dialog.x = dx or display.contentCenterX - dialog.width / 2
				dialog.y = dy or display.contentCenterY - dialog.height / 2
				-- todo: clamping...
			end
		end
	end
end

_Dialog_ = M.Dialog

return M