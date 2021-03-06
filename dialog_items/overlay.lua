--- Helpers to populate a dialog with overlay-launching UI elements.

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
local button = require("solar2d_ui.widgets.button")
local utils = require("solar2d_ui.dialog_impl.utils")

-- Solar2D modules --
local composer = require("composer")

-- Exports --
local M = {}

--
--
--

--
local function AuxChooseAudio (mode)
	return function(button)
		composer.showOverlay("s3_editor.overlay.ChooseAudio", {
			params = {
				assign = function(name)
					utils.UpdateObject(button, name)

					button:SetText(name)
				end,
				mode = mode
			}
		})
	end
end

--[[
	name:addEventListener("closing", function(event)
		local old_text = list:GetSelection()
		local index = list:Find(old_text)

		if index and event.closed_by_key then
			local str = event.target:GetText()

			items[index].name = str

			list:Update(index, str)

			common.Dirty()
		else
			event.target:SetText(old_text)
		end
	end)

	-- TODO: Incorporate into buttons...
]]

-- --
local PickerOpts = { skin = "small_text_button" }

--- DOCME
function M:AddMusicPicker (options)
	local picker = button.Button(self:ItemGroup(), "30%", "8.33%", AuxChooseAudio("stream"), PickerOpts)

	self:CommonAdd(picker, options, true)

	picker:SetText(utils.GetValue(picker) or "")
end

--- DOCME
function M:AddSoundPicker (options)
	local picker = button.Button(self:ItemGroup(), "30%", "8.33%", AuxChooseAudio("sound"), PickerOpts)

	self:CommonAdd(picker, options, true)

	picker:SetText(utils.GetValue(picker) or "")
end

return M