--- Miscellaneous helpers to populate a dialog with UI elements (primarily, where a method
-- either is hard to group, or there is only one method).

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
local format = string.format
local type = type

-- Modules --
local button = require("corona_ui.widgets.button")
local color_picker = require("corona_ui.widgets.color_picker")
local layout = require("corona_ui.utils.layout")
local touch = require("corona_ui.utils.touch")
local utils = require("corona_ui.dialog_impl.utils")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
local RGB = {}

--
local function OnColorChange (event)
	RGB.r, RGB.g, RGB.b = event.r, event.g, event.b

	utils.UpdateObject(event.target, RGB)
end

--- DOCME
function M:AddColorPicker (options)
	local picker = color_picker.ColorPicker(self:ItemGroup(), 300, 240)

	self:CommonAdd(picker, options, true)

	local color = options and self:GetValue(options.value_name)

	if color then
		picker:SetColor(color.r, color.g, color.b)
	end

	picker:addEventListener("color_change", OnColorChange)
end

--- DOCME
-- @ptable options
function M:AddImage (options)
	--
	local dim, image = layout.ResolveX(options and options.dim or "6.67%")

	if options and options.file then
		image = display.newImageRect(self:ItemGroup(), options.file, dim, dim)
	else
		image = display.newRoundedRect(self:ItemGroup(), 0, 0, dim, dim, layout.ResolveY("2.5%"))
	end

	self:CommonAdd(image, options)
end

--- DOCME
-- @ptable options
function M:AddString (options)
	local sopts, text = {}

	if options then
		if options.before then
			self:CommonAdd(false, { text = options.before, continue_line = true }, true)
		end

		if options.value_name then
			text = self:GetValue(options.value_name)
		else
			text = options.text
		end

		sopts.name = options.name
		sopts.value_name = options.value_name
		sopts.get_editable_text = options.get_editable_text
		sopts.set_editable_text = options.set_editable_text

		local adjust = options.adjust_to_size

		if adjust then
			sopts.adjust_to_size = true

			if type(adjust) == "number" or type(adjust) == "string" then
				sopts.max_adjust_width = adjust
			end
		end
	end

	sopts.text = text or ""

	self:CommonAdd(false, sopts, options and options.is_static)
end

-- Drag touch listener
local DragTouch = touch.DragParentTouch_Child(1, { find = utils.GetDialog }) -- brittle, depends on back index...

--- DOCME
-- @string[opt] dir
-- @string type
function M:StockElements (dir)--, type)
	--
	local exit = button.Button(self:ItemGroup(), "3.125%", "5.2%", function()
		self:RemoveSelf()
	end, "X")

	self:CommonAdd(exit, { continue_line = true })

	--
	local bar = display.newRoundedRect(self:ItemGroup(), 0, 0, 1, exit.height, layout.ResolveY("2.5%"))

	bar:addEventListener("touch", DragTouch)
	bar:setFillColor(0, 0, 1)
	bar:setStrokeColor(0, 0, .5)

	bar.strokeWidth = 2

	utils.SetProperty(bar, "type", "separator", utils.GetNamespace(self))

	self:CommonAdd(bar)

	--
	if dir then
		self:AddImage{ file = format("%s_Assets/%s_Thumb.png", dir, type), dim = "6%", continue_line = true }
	end

	--
	self:AddString{ value_name = "name", before = "Name:", adjust_to_size = "30%" }
end

-- Export the module.
return M