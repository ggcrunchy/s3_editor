--- Overlay used to get text in the editor.

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
local type = type

-- Modules --
local net = require("corona_ui.patterns.net")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")

-- Get text overlay --
local Overlay = composer.newScene()

--
function Overlay:create (_)
	net.Blocker(self.view, { gray = .4, alpha = .3, on_touch = composer.hideOverlay })
end

Overlay:addEventListener("create")

local StringFunc, Text, Arg

local function UserInput (event)
    if event.phase == "ended" or event.phase == "submitted" then
		if event.phase == "submitted" then
			StringFunc("set", Arg, Text)
		end

		composer.hideOverlay()
    end
end

--
function Overlay:show (event)
	if event.phase == "did" then
		local params = event.params

		if type(params) == "table" then
			StringFunc, Arg = params.func, params.arg
		else
			StringFunc = params
		end
			
		assert(type(StringFunc) == "function", "No string function provided")	

		local x, y = StringFunc("where", Arg)

		x, y = x or display.contentCenterX, y or display.contentCenterY

		Text = native.newTextField(x, y, 180, 30)

		local input_type = StringFunc("input_type")

		if input_type then
			Text.inputType = input_type
		end

		StringFunc("get", Arg, Text)

		Text:addEventListener("userInput", UserInput)
	end
end

Overlay:addEventListener("show")

--
function Overlay:hide (event)
	if event.phase == "did" then
		Text:removeSelf()

		StringFunc, Text, Arg = nil
	end
end

Overlay:addEventListener("hide")

return Overlay