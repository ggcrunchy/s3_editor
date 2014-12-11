--- Helpers to populate a dialog with spinner elements.

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
local min = math.min

-- Modules --
local button = require("corona_ui.widgets.button")
local table_funcs = require("tektite_core.table.funcs")
local utils = require("corona_ui.dialog_impl.utils")

-- Exports --
local M = {}

--- DOCME
-- @ptable options
function M:AddSpinner (options)
	local sopts = table_funcs.Copy(options)

	local inc = sopts.inc or 1
	local nmax = sopts.max
	local nmin = sopts.min
	local skip = inc ~= 0 and sopts.skip
	local value = self:GetValue(sopts.value_name) or 0

	sopts.is_static = true
	sopts.text = value .. ""

	local name = sopts.name

	if name == true then
		name = sopts.value_name
	end

	name = name or {}

	sopts.name = name

	self:AddString(sopts)
	self:CommonAdd(button.Button(self:ItemGroup(), 40, 30, function()
		local str = self:Find(name)

		repeat
			value = value - inc
		until value ~= skip

		if nmin then
			value = max(nmin, value)
		end

		utils.UpdateObject(str, value)

		str.text = value .. ""
	end, "-"), { continue_line = true })
	self:CommonAdd(button.Button(self:ItemGroup(), 40, 30, function()
		local str = self:Find(name)

		repeat
			value = value + inc
		until value ~= skip

		if nmax then
			value = min(nmax, value)
		end

		utils.UpdateObject(str, value)

		str.text = value .. ""
	end, "+"))
end

-- ^^ This basically now exists, in "widgets"...

-- Export the module.
return M