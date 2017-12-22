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
local table_view_patterns = require("corona_ui.patterns.table_view")
local utils = require("corona_ui.dialog_impl.utils")

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

--- DOCME
-- @ptable options
function M:AddFamilyList (options)
	AuxListbox(self, options, object_vars.families)
end

--- DOCME
-- @ptable options
function M:AddListbox (options)
	AuxListbox(self, options, options)
end

-- Export the module.
return M