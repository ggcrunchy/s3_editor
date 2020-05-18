--- Overlay used to show help in the editor.

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
local help = require("s3_editor.Help")
local layout = require("solar2d_ui.utils.layout")
local layout_dsl = require("solar2d_ui.utils.layout_dsl")
local net = require("solar2d_ui.patterns.net")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Help overlay --
local Overlay = composer.newScene()

-- --
local RectGroup, RectStash

local function Over (icon)
	local x, y = icon:localToContent(0, 0)

	for i = 1, RectGroup.numChildren do
		local rect = RectGroup[i]
		local cx, cy, dw, dh = rect.x, rect.y, .5 * rect.width, .5 * rect.height
		local xmin, ymin, xmax, ymax = cx - dw, cy - dh, cx + dw, cy + dh

		if x >= xmin and x <= xmax and y >= ymin and y <= ymax then
			return rect
		end
	end
end

local ColorParams = { time = 150 }

local function SetColor (rect, r, g, b)
	ColorParams.r, ColorParams.g, ColorParams.b = r, g, b

	transition.to(rect.fill, ColorParams)
end

local function SetOver (icon, over)
	if over then
		SetColor(over, 1, 0, 0)
	end

	icon.m_over = over
end

local function ShowText (over)
	local mgroup = Overlay.message_group
	local rect, text = mgroup[1], mgroup[2]

	text.text = over.m_message
	rect.height = max(layout.ResolveY("10.5%"), text.contentHeight + layout.ResolveY("2.1%"))

	mgroup.isVisible = true
end

-- --
local TouchBodiesOpts = {
	began = function(icon)
		SetOver(icon, Over(icon))
	end,

	ended = function(icon)
		local over = icon.m_over

		if over then
			ShowText(over)

			icon.m_over = nil
		else
			composer.hideOverlay(true)
		end
	end,

	get_overlay_view = function()
		return Overlay.view
	end,

	post_move = function(icon)
		local old, new = icon.m_over, Over(icon)

		if old ~= new then
			if old then
				SetColor(old, 1, 1, 0)
			end

			SetOver(icon, new)
		end
	end
}

-- --
local BlockerOpts = {
	on_touch = function(event)
		if event.phase == "cancelled" or event.phase == "ended" then
			Overlay.message_group.isVisible = false

			composer.hideOverlay(true)
		end

		return true
	end
}

--
function Overlay:create ()
	net.Blocker(self.view, BlockerOpts)

	--
	help.SetTouchFuncBodies(TouchBodiesOpts)

	--
	RectGroup, RectStash = display.newGroup(), display.newGroup()

	self.view:insert(RectGroup)
	self.view:insert(RectStash)

	RectGroup.isVisible, RectStash.isVisible = false, false

	--
	self.help_group = display.newGroup()

	self.view:insert(self.help_group)

	--
	self.message_group = display.newGroup()

	local rect = display.newRoundedRect(self.message_group, 0, 0, display.contentWidth / 2, 1, layout.ResolveX("3.125%"))

	rect:setFillColor(0, 0, 1, .75)
	rect:setStrokeColor(0, 1, 0, .25)

	rect.x, rect.y = display.contentCenterX, display.contentCenterY
	rect.strokeWidth = 5

	local w = layout.ResolveX("6.25%")

	display.newText(self.message_group, "", rect.x, rect.y, rect.width - w, 0, native.systemFontBold, layout.ResolveY("2.5%"))

	self.message_group.isVisible = false

	self.view:insert(self.message_group)
end

Overlay:addEventListener("create")

-- --
local Count, W, H

--
local function AssignRects (object, message, w, h)
	local bounds = (object.isVisible and object.alpha > 0) and object.contentBounds

	if bounds and bounds.xMax >= 0 and bounds.xMin <= W and bounds.yMax >= 0 and bounds.yMin <= H then
		Count = Count + 1

		if Count > RectGroup.numChildren then
			local n, rect = RectStash.numChildren

			if n > 0 then
				rect = RectStash[n]
				rect.width, rect.height = w, h

				RectGroup:insert(rect)
			else
				rect = display.newRect(RectGroup, 0, 0, w, h)

				rect:setFillColor(1, 1, 0, .125)
				rect:setStrokeColor(1, 1, 0)

				rect.strokeWidth = 2
			end

			layout.CenterAtX(rect, layout.CenterX(object))
			layout.TopAlignWith(rect, object)

			rect.m_message = message
		end
	end
end

--
function Overlay:show (event)
	if event.phase == "did" then
		Count, W, H = 0, display.contentWidth, display.contentHeight

		help.Visit(AssignRects)

		for i = RectGroup.numChildren, Count + 1, -1 do
			RectStash:insert(RectGroup[i])
		end

		RectGroup.isVisible = Count > 0
	end
end

Overlay:addEventListener("show")

--
function Overlay:hide (event)
	if event.phase == "did" then
		for i = self.help_group.numChildren, 1, -1 do
			self.help_group:remove(i)
		end

		RectGroup.isVisible = false
	end
end

Overlay:addEventListener("hide")

return Overlay