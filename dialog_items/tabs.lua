--- Helpers to populate a dialog with tab elements.

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
local ipairs = ipairs

-- Modules --
local layout = require("corona_ui.utils.layout")
local table_funcs = require("tektite_core.table.funcs")
local tabs_patterns = require("corona_ui.patterns.tabs")
local utils = require("corona_ui.dialog_impl.utils")

-- Exports --
local M = {}

-- --
local DirTabs

--- DOCME
-- @ptable options
function M:AddDirectionTabs (options)
	options = table_funcs.Copy(options)
	DirTabs = DirTabs or { "up", "down", "left", "right" }
	options.buttons = DirTabs

	self:AddTabs(options)
end

-- --
local TabButtons = setmetatable({}, { __mode = "k" })

-- Tab button pressed
local function TabButtonPress (event) -- TODO: This seems kind of brittle :P
	local label = event.target.label.text

	utils.UpdateObject(event.target.parent, label)

	return true
end

--
local function TabButtonsFromLabels (labels)
	if TabButtons[labels] then
		return TabButtons[labels]
	elseif labels then
		local buttons = {}

		for _, label in ipairs(labels) do
			buttons[#buttons + 1] = { label = label, onPress = TabButtonPress }
		end

		TabButtons[labels] = buttons

		return buttons
	end
end

--- DOCME
-- @ptable options
function M:AddTabs (options)
	if options then
		options = table_funcs.Copy(options)
		options.width = options.width or #(options.buttons or "") * layout.ResolveX("11.25%")
		options.buttons = TabButtonsFromLabels(options.buttons)

		local tabs = tabs_patterns.TabBar(self:ItemGroup(), options.buttons, options)
		local choice = self:GetValue(options.value_name)

		for i = 1, #(options.buttons or "") do
			if choice == options.buttons[i].label then
				tabs:setSelected(i, true)

				break
			end
		end

		utils.SetProperty(tabs, "type", "widget", utils.GetNamespace(self))

		self:CommonAdd(tabs, options)

		-- TODO: Hack!
		tabs_patterns.TabsHack(self:ItemGroup(), tabs, #options.buttons)
		-- /TODO
	end
end

-- Export the module.
return M