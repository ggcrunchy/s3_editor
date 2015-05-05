--- Overlay used to choose audio files in the editor.

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
local net = require("corona_ui.patterns.net")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Corona modules --
local composer = require("composer")

-- Choose audio overlay --
local Overlay = composer.newScene()

-- Drag touchy listener
local DragTouch = touch.DragParentTouch()

--
local function Backdrop (group, w, h, corner)
	local backdrop = display.newRoundedRect(group, 0, 0, w, h, corner)

	backdrop:addEventListener("touch", DragTouch)
	backdrop:setFillColor(.375, .675)
	backdrop:setStrokeColor(.125)
	backdrop:translate(w / 2, h / 2)

	backdrop.strokeWidth = 2

	return backdrop
end

--
function Overlay:create ()
	net.Blocker(self.view)

	Backdrop(self.view, 350, 350, 22)
	-- ^^^ Problem: layout modules not robust for dialogs (yet...)
end

Overlay:addEventListener("create")

--
function Overlay:show (event)
	if event.phase == "did" then
		--
	end
end

Overlay:addEventListener("show")

--
function Overlay:hide (event)
	if event.phase == "did" then
		--
	end
end

Overlay:addEventListener("hide")

return Overlay