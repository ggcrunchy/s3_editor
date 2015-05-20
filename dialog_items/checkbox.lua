--- Helpers to populate a dialog with checkbox UI elements.

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
local max = math.max

-- Modules --
local checkbox = require("corona_ui.widgets.checkbox")
local layout = require("corona_ui.utils.layout")
local utils = require("corona_ui.dialog_impl.utils")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- Bitfield checkbox response
local function OnCheck_Field (cb, is_checked)
	local value = utils.GetValue(cb.parent)

	if value ~= nil then
		if is_checked then
			value = value + cb.m_flag
		else
			value = value - cb.m_flag
		end

		utils.UpdateObject(cb.parent, value)
	end
end

--- DOCME
function M:AddBitfield (options)
	local bits, sep = options and self:GetValue(options.value_name) or 0, layout.ResolveX("1.25%")
	local bf, nstrs = display.newGroup(), #(options and options.strs or "")
	local prev, w = 0, 0

	self:ItemGroup():insert(bf)

	for i = 1, nstrs do
		local cb, low = checkbox.Checkbox(bf, "5%", "8.33%", OnCheck_Field), bits % 2

		cb.anchorX, cb.x = 0, sep
		cb.m_flag = 2^(i - 1)

		layout.PutBelow(cb, prev, sep)

		if low ~= 0 then
			cb:Check(true)
		end

		local text = display.newText(bf, options.strs[i], 0, cb.y, native.systemFontBold, layout.ResolveY("4.6%"))

		layout.PutRightOf(text, cb, sep)

		bits, prev, w = (bits - low) / 2, cb, max(w, layout.RightOf(text, sep))
	end

	local region = display.newRoundedRect(bf, 0, 0, w, layout.Below(prev, sep), layout.ResolveX("1.5%"))

	region:setFillColor(0, 0)
	region:setStrokeColor(0)
	region:toBack()

	region.anchorX, region.x = 0, 0
	region.anchorY, region.y = 0, 0
	region.strokeWidth = 3

	self:CommonAdd(bf, options, true)
end

-- Checkbox response
local function OnCheck (cb, is_checked)
	utils.UpdateObject(cb, is_checked)
end

--- DOCME
-- @ptable options
function M:AddCheckbox (options)
	local cb = checkbox.Checkbox(self:ItemGroup(), "5%", "8.33%", OnCheck)

	self:CommonAdd(cb, options, true)

	local is_checked = options and self:GetValue(options.value_name)

	cb:Check(is_checked)
end

-- ^^^ TODO: "widgets"...

-- Export the module.
return M