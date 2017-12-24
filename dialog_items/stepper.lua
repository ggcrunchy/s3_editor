--- Helpers to populate a dialog with stepper elements.

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
local assert = assert
local max = math.max
local min = math.min
local pairs = pairs
local tonumber = tonumber
local type = type

-- Modules --
local button = require("corona_ui.widgets.button")
local number = require("s3_objects.grammars.number")
local table_funcs = require("tektite_core.table.funcs")
local utils = require("corona_ui.dialog_impl.utils")

-- Corona globals --
local display = display

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

--
--
--

-- --
local Steppers = {}

--
local function Finalize (editable)
	Steppers[editable] = nil
end

--
local function UpdateValue (stepper, value)
	utils.UpdateObject(stepper, value)
end

local function Correct (editable, stepper, correct_stepper)
	local text = editable and editable:GetText()
	local value = tonumber(text)

	if value then -- not nan or infinite
		if value < stepper.m_min then
			editable:SetText(stepper.m_min)
		elseif stepper.m_max and value > stepper.m_max then
			editable:SetText(stepper.m_max)
		elseif not correct_stepper then
			editable:SetText(stepper:getValue())
		elseif value ~= stepper:getValue() then
			stepper:setValue(value)

			UpdateValue(stepper, value)
		end
	end
end

--
local function UpdateStepper (event)
	local phase, stepper = event.phase, event.target

	if phase == "increment" or phase == "decrement" then
		Correct(stepper.m_editable, stepper)
		UpdateValue(stepper, event.value)
	end
end

--- DOCME
-- @ptable options
function M:AddStepper (options)
	local stepper = widget.newStepper{
		width = options.width, height = options.height,
		initialValue = self:GetValue(options.value_name),
		maximumValue = options.max,
		minimumValue = options.min,
		onPress = UpdateStepper,
		timerIncrementSpeed = 350
	}

	utils.SetProperty(stepper, "type", "widget", utils.GetNamespace(self))

	self:ItemGroup():insert(stepper)
	self:CommonAdd(stepper, options, true)

	local editable = options.editable

	if editable then
		if type(editable) == "string" then
			editable = assert(self:Find(editable), "Bad editable name")
		end

		stepper.m_editable, Steppers[editable] = editable, stepper
		stepper.m_min, stepper.m_max = options.min or 0, options.max

		Correct(editable, stepper, true)

		editable:addEventListener("finalize", Finalize)
	end
end

--- DOCME
-- @ptable options
function M:AddStepper_Old (options) -- TODO: keep?
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
	self:CommonAdd(button.Button(self:ItemGroup(), "5%", "6.25%", function()
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
	self:CommonAdd(button.Button(self:ItemGroup(), "5%", "6.25%", function()
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

--- DOCME
function M:AddStepperWithEditable (options)
	local topts, eopts, sopts = {}, {}, {}

	assert(options.text, "Missing text")
	assert(options.value_name, "Missing value name")

	for k, v in pairs(options) do
		if k == "text" then
			topts[k] = v
		elseif k == "value_name" then
			eopts[k], sopts.editable = v, v
		elseif k ~= "is_static" and k ~= "editable" then
			sopts[k] = v
		-- TODO: any relevant properties to the other two
		end
	end

	topts.is_static, topts.continue_line, eopts.continue_line = true, true, true
	sopts.set_editable_text = self.SetText_StepperAware

	self:AddString(topts)
	self:AddString(eopts)
	self:AddStepper(sopts)
end

--- DOCME
function M.SetText_StepperAware (editable, text)
	local stepper = assert(Steppers[editable], "No stepper has been bound")

	number.set_editable_text(editable, text)

	if display.isValid(stepper) then
		Correct(editable, stepper, true)
	end
end

-- Export the module.
return M