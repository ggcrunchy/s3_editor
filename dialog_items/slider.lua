--- Helpers to populate a dialog with slider UI elements.

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

-- Extension imports --
local round = math.round

-- Modules --
local utils = require("solar2d_ui.dialog_impl.utils")
local layout = require("solar2d_ui.utils.layout")

-- Solar2D globals --
local display = display

-- Solar2D modules --
local widget = require("widget")

-- Exports --
local M = {}

--
--
--

--
local function Pad (igroup, w, h) -- the thumb sliders bleed out a bit, so pad around them
	local pad = display.newRect(igroup, 0, 0, w, h)

	pad.isVisible = false

	return pad
end

--
local function UpdateSlider (event)
	utils.UpdateObject(event.target, event.value / 100)
end

-- --
local PadDim = 5

local function AuxSlider(dialog, options, params)
	local igroup, pad_dim = dialog:ItemGroup(), options.pad_dim or PadDim

	if not options.continue_line then
		dialog:Update(Pad(igroup, 1, pad_dim))
		dialog:NewLine()
	end

	dialog:Update(Pad(igroup, pad_dim, 1))

	params.listener = UpdateSlider
	params.value = round((dialog:GetValue(options.value_name) or 0) * 100)

	local slider = widget.newSlider(params)

	utils.SetProperty(slider, "type", "widget", utils.GetNamespace(dialog))

	igroup:insert(slider)

	dialog:CommonAdd(slider, options, true)
end

--- DOCME
function M:AddHorizontalSlider (options)
	AuxSlider(self, options, { width = options.width or layout.ResolveX("20%") })
end

--- DOCME
function M:AddVerticalSlider (options)
	AuxSlider(self, options, { height = options.height or layout.ResolveY("20%"), orientation = "vertical" })
end

return M