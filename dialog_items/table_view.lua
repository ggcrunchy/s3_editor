--- Helpers to populate a dialog with table view elements.

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
local object_vars = require("config.ObjectVariables")
local menu = require("solar2d_ui.widgets.menu")
local table_funcs = require("tektite_core.table.funcs")
local table_view_patterns = require("solar2d_ui.patterns.table_view")
local utils = require("solar2d_ui.dialog_impl.utils")

-- Exports --
local M = {}

--
--
--

local ListboxOpts = {
	press = function(event)
		utils.UpdateObject(event.listbox, event.str)
	end
}

local function AuxListbox (dialog, options, list)
	local listbox = table_view_patterns.Listbox(dialog:ItemGroup(), ListboxOpts)

	utils.SetProperty(listbox, "type", "widget", utils.GetNamespace(dialog))

	listbox:AppendList(list)
	dialog:CommonAdd(listbox, options, true)

	local def_index = utils.GetValue(listbox)

	def_index = def_index and listbox:Find(def_index)

	if def_index then
		listbox:Select(def_index)
	end
end

--
local function UpdateDropdown (event)
	utils.UpdateObject(event.target, event.text)
end

local function AuxDropdown (dialog, options, column)
	local opts = table_funcs.Copy(options)

	opts.group, opts.column = dialog:ItemGroup(), column

	local dropdown = menu.Dropdown(opts)
	local stash = dropdown:StashDropdowns() -- avoid including incorporate dropdown in the layout

	dialog:CommonAdd(dropdown, options, true)

	dropdown:RestoreDropdowns(stash)
	dropdown:RelocateDropdowns(dialog:UpperGroup())
	dropdown:Select(utils.GetValue(dropdown))
	dropdown:addEventListener("item_change", UpdateDropdown)
end

--- DOCME
function M:AddDropdown (options)
	AuxDropdown(self, options, options.column)
end

--- DOCME
-- @ptable options
function M:AddFamilyList (options)
	AuxDropdown(self, options, object_vars.families)
end

--- DOCME
-- @ptable options
function M:AddListbox (options)
	AuxListbox(self, options, options)
end

return M