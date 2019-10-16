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

-- Extension imports --
local round = math.round

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

local function AdjustForGet (stepper, value)
	return (stepper.m_scale or 1) * value
end

local function AdjustForSet (stepper, value)
	return value / (stepper.m_scale or 1)
end

--
local function UpdateValue (stepper, value)
	utils.UpdateObject(stepper, AdjustForGet(stepper, value))
end

local function Correct (editable, stepper, correct_stepper)
	local text = editable:GetText()
	local value, adjust = tonumber(text)

	if value then -- not nan or infinite
		value = AdjustForSet(stepper, value)

		if value < stepper.m_min then
			adjust = stepper.m_min
		elseif stepper.m_max and value > stepper.m_max then
			adjust = stepper.m_max
		elseif not correct_stepper then
			editable:SetText(AdjustForGet(stepper, stepper:getValue()))
		end

		if adjust or correct_stepper then
			if adjust then
				value = adjust

				editable:SetText(AdjustForGet(stepper, value))
			end

			local rounded = round(value)

			if rounded ~= stepper:getValue() then
				stepper:setValue(rounded)

				UpdateValue(stepper, rounded)
			end
		end
	end
end

local function CorrectStatic (static, stepper)
	static.text = AdjustForGet(stepper, stepper:getValue())
end

--
local function UpdateStepper (event)
	local phase, stepper = event.phase, event.target

	if phase == "increment" or phase == "decrement" then
		local editable, static = stepper.m_editable, stepper.m_static

		if editable then
			Correct(editable, stepper)
		elseif static then
			CorrectStatic(static, stepper)
		end

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

	stepper.m_min, stepper.m_max, stepper.m_scale = options.min or 0, options.max, options.scale

	local editable, static = options.editable, options.static

	if editable then
		self:AttachEditable(stepper, editable)
	elseif static then
		self:AttachStaticText(stepper, static)
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

local function HasFloats (dialog, opts)
	local maxv, minv, scalev, value = opts.max or 0, opts.min or 0, opts.scale or 0, dialog:GetValue(opts.value_name)

	return maxv % 1 ~= 0 or (minv % 1 ~= 0 and 1 / minv ~= 0) or scalev % 1 ~= 0 or value % 1 ~= 0
end

--- DOCME
function M:AddStepperWithEditable (options)
	local eopts, sopts = {}, {}

	assert(options.value_name, "Missing value name")

	for k, v in pairs(options) do
		if k == "before" or k == "mode" then
			eopts[k] = v
		elseif k == "value_name" then
			eopts[k], sopts.editable = v, v
		elseif k ~= "editable" then
			sopts[k] = v
		-- TODO: any relevant text properties
		end
	end

	eopts.continue_line, eopts.set_editable_text = true, self.SetText_StepperAware

	local any_floats = HasFloats(self, options)

	if not eopts.mode then
		eopts.mode = any_floats and "decimal" or "nums"
	else
		assert(not any_floats or eopts.mode == "decimal", "Floats detected, requires `decimal` mode")
	end

	self:AddString(eopts)
	self:AddStepper(sopts)
end

--- DOCME
function M:AddStepperWithStaticText (options)
	local topts, sopts = {}, {}

	assert(options.value_name, "Missing value name")

	for k, v in pairs(options) do
		if k == "before" or k == "value_name" then
			topts[k] = v
		elseif k == "text" then
			sopts.before = v
		elseif k ~= "editable" and k ~= "static" then
			sopts[k] = v
		-- TODO: any relevant text properties
		end
	end

	local stepper_name = sopts -- nonce

	sopts.continue_line, sopts.name, topts.is_static = true, stepper_name, true

	self:AddStepper(sopts)
	self:AddString(topts)
	self:AttachStaticText(self:Find(stepper_name), options.value_name)
end

local function AuxAttach (dialog, stepper, object, err)
	assert(not (stepper.m_editable or stepper.m_static), "Already has editable or static text")

	if type(object) == "string" then
		object = assert(dialog:Find(object), "Bad editable name")
	end

	return object
end

--- DOCME
function M:AttachEditable (stepper, editable)
	editable = AuxAttach(self, stepper, editable, "Bad editable name")

	stepper.m_editable, Steppers[editable] = editable, stepper

	Correct(editable, stepper, true)

	editable:addEventListener("finalize", Finalize)
end

--- DOCME
function M:AttachStaticText (stepper, static)
	static = AuxAttach(self, stepper, static, "Bad static string name")

	stepper.m_static = static

	CorrectStatic(static, stepper)
end

--- DOCME
function M.SetText_StepperAware (editable, text)
	local stepper = assert(Steppers[editable], "No stepper has been bound")

	number.set_editable_text(editable, text)

	if display.isValid(stepper) then
		Correct(editable, stepper, true)
	end
end

return M