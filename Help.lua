--- Help system components.

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
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local sort = table.sort

-- Modules --
local touch = require("solar2d_ui.utils.touch")

-- Corona globals --
local display = display

-- Corona modules --
local composer = require("composer")

-- Exports --
local M = {}

--
--
--

-- --
local Entries

-- --
local Help

--- DOCME
function M.CleanUp ()
	Entries, Help = nil
end

-- --
local MaxDepth

--- DOCME
function M.Init ()
	Entries, Help, MaxDepth = {}, {}, 0
end

local HelpContext = {}

HelpContext.__index = HelpContext

--- DOCME
function HelpContext:Add (object, help)
	assert(not self.m_indices, "Cannot add to registered context")
	assert(help, "No help text provided")

	local n, cur = #Entries, self.m_n

	assert(not cur or n == cur, "Previous context failed to register entries")
	assert(not self[object], "Help already added")

	Entries[n + 1] = object
	Entries[n + 2] = help
	Entries[n + 3] = object.width
	Entries[n + 4] = object.height

	self[object], self.m_n = n + 1, #Entries
end

local function DepthComp (i1, i2)
	return Entries[i1].m_help_depth < Entries[i2].m_help_depth
end

local function FindDepth (context, object, stage)
	local n = 0

	repeat
		object = object.parent
		n = n + (context[object] and 1 or 0)
	until not object or object == stage

	if n > MaxDepth then
		MaxDepth = n
	end

	return n
end

--- DOCME
function HelpContext:Register ()
	assert(not self.m_indices, "Already registered")
	assert(self.m_n == #Entries, "Previous context failed to register entries")

	local stage, indices = display.getCurrentStage(), {}

	self.m_n = nil

	for object, index in pairs(self) do
		object.m_help_depth = FindDepth(self, object, stage)
		indices[#indices + 1] = index
	end

	sort(indices, DepthComp)

	for _, index in ipairs(indices) do
		local object = Entries[index]

		self[object], object.m_help_depth = nil
	end

	self.m_indices, Help[indices] = indices, true -- show by default
end

--- DOCME
function HelpContext:Show (show)
	local indices = assert(self.m_indices, "Unregistered context")

	Help[indices] = not not show
end

--- DOCME
function M.NewContext ()
	return setmetatable(context, HelpContext)
end

-- --
local GetOverlayView

-- --
local Began, Ended, PostMove

--- DOCME
function M.SetTouchFuncBodies (opts)
	Began, Ended, PostMove = opts.began, opts.ended, opts.post_move
	GetOverlayView = assert(opts.get_overlay_view, "Overlay view getter is required")
end

-- --
local HelpOpts = { isModal = true }

--- DOCME
M.TouchFunc = touch.DragParentTouch{
	find = function(icon, how)
		if how == "into" then
			return GetOverlayView()
		else
			return icon.parent
		end
	end, hoist = true,

	on_began = function(_, object)
		if Began then
			Began(object)
		end
	end,

	on_init = function(object)
		HelpOpts.params = object

		composer.showOverlay("s3_editor.overlay.Help", HelpOpts)

		HelpOpts.params = nil
	end,

	on_post_move = function(_, object)
		if PostMove then
			PostMove(object)
		end
	end,

	on_ended = function(_, object)
		if Ended then
			Ended(object)
		end
	end
}

--- DOCME
function M.Visit (func)
	for indices, active in pairs(Help) do
		if active then
			for _, index in ipairs(indices) do
				func(Entries[index], Entries[index + 1], Entries[index + 2], Entries[index + 3])
			end
		end
	end
end

return M