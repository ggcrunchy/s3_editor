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
local audio_patterns = require("corona_ui.patterns.audio")
local button = require("corona_ui.widgets.button")
local common_ui = require("s3_editor.CommonUI")
local layout = require("corona_ui.utils.layout")
local net = require("corona_ui.patterns.net")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local audio = audio
local display = display
local system = system

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

-- --
local Source, SourceName

--
local function Close ()
	if Source then
		audio.stop()
		audio.dispose(Source)
	end

	Source, SourceName = nil
end

-- --
local Base = system.ResourceDirectory
-- ^^ TODO: Add somewhere to pull down remote files... and, uh, support

-- --
local Current

-- --
local Assign, Mode

-- Helper to load or reload the music list
local function Reload (songs)
	-- If the file was removed while playing, try to close the source before problems arise.
	if not songs:Find(SourceName) then
		Close()
	end

	-- Provide the current element as an alternative in case the selection was erased.
	return songs:Find(Current)
end

--
function Overlay:create (event)
	net.Blocker(self.view) -- :/

	--
	local backdrop = Backdrop(self.view, 350, 300, 22)
	local dir = event.params.mode == "stream" and "Music" or "SFX"
	local choices = audio_patterns.AudioList(self.view, {
		x = layout.CenterX(backdrop), top = 30,
		base = Base, path = dir, on_reload = Reload
	})

	common_ui.Frame(choices, 1, 0, 0)

	--
	local bottom, left = layout.Below(backdrop, -10), layout.LeftOf(choices)
	local ok = button.Button_XY(self.view, "right_of " .. left, "above " .. bottom, 120, 40, function()
		Assign(SourceName ~= nil and (dir .. "/" .. SourceName))

		composer.hideOverlay()
	end, "OK")
	local cancel = button.Button_XY(self.view, 0, ok.y, ok.width, ok.height, function()
		composer.hideOverlay()
	end, "Cancel")

	layout.PutRightOf(cancel, ok, 10)

	--
	local below_choices = layout.Below(choices, 10)

	button.Button_XY(self.view, ok.x, "below " .. below_choices, ok.width, ok.height, function()
		Close()

		local selection = choices:GetSelection()

		if selection then
			local path, opts = dir .. "/" .. selection

			if Mode == "stream" then
				Source, opts = audio.loadStream(path, Base), { fadein = 1500, loops = -1 }
			else
				Source = audio.loadSound(path, Base)
			end

			if Source then
				SourceName = selection

				audio.play(Source, opts)
			end
		end
	end, "Listen")

	choices:Init()
end

Overlay:addEventListener("create")

--
function Overlay:show (event)
	if event.phase == "did" then
		local params = event.params

		Assign, Mode = params.assign, params.mode
	end
end

Overlay:addEventListener("show")

--
function Overlay:hide (event)
	if event.phase == "did" then
		Close()

		Assign, Mode = nil
	end
end

Overlay:addEventListener("hide")

return Overlay