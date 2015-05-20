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
local type = type

-- Modules --
local button = require("corona_ui.widgets.button")
local grid = require("s3_editor.Grid")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local net = require("corona_ui.patterns.net")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")

-- Help overlay --
local Overlay = composer.newScene()

--
function Overlay:create ()
	net.Blocker(self.view)

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

	local w, tx, ty = layout.ResolveX("6.25%"), layout_dsl.EvalPos("25%", "41.67%")
	local text = display.newText(self.message_group, "", tx, ty, rect.width - w, 0, native.systemFontBold, layout.ResolveY("5.21%"))

	self.message_group.isVisible = false

	self.view:insert(self.message_group)

	--
	button.Button_XY(self.view, "from_right -12.5%", "below 5.2%", "4.375%", "7.3%", function()
		composer.hideOverlay(true)
	end, "X")
end

Overlay:addEventListener("create")

--
local ShowText = touch.TouchHelperFunc(function(_, node)
	local mgroup = Overlay.message_group
	local rect, text = mgroup[1], mgroup[2]

	text.text = node.m_text
	text.x, text.y = display.contentCenterX, display.contentCenterY
	rect.height = max(layout.ResolveY("62.5%"), text.contentHeight + layout.ResolveY("2.1%"))

	net.AddNet_Hide(Overlay.view, mgroup)

	mgroup.isVisible = true
end)

--
function Overlay:show (event)
	if event.phase == "did" then
		local function on_help (_, text, binding)
			if text and binding and (binding.isVisible or binding.m_is_proxy) then
				local bounds = binding.contentBounds

				--
				local radius = layout.ResolveX("1.875%")
				local minx, miny = bounds.xMin, bounds.yMin
				local maxx, maxy = bounds.xMax, bounds.yMax
				local help = display.newRoundedRect(self.help_group, .5 * (minx + maxx), .5 * (miny + maxy), maxx - minx, maxy - miny, radius)

				help:setFillColor(1, 1, 0, .125)
				help:setStrokeColor(1, 1, 0)

				help.strokeWidth = 4

				--
				local dx, dw, n = 0, 0, 1 

				if type(text) ~= "string" then
					n = #text

					if n > 1 then
						dw = help.width / n
						dx = (n - 1) * dw / 2
					else
						text = text[1]
					end
				end

				--
				local x, y = help.x - dx, help.y

				for i = 1, n do
					local node = display.newCircle(self.help_group, x, y, radius)

					node:addEventListener("touch", ShowText)
					node:setFillColor(0, 0, 1)

					--
					if n > 1 then
						node.m_text = text[i]

						if i < n then
							local x2 = x + .5 * dw
							local sep = display.newLine(self.help_group, x2, miny, x2, maxy)

							sep:setStrokeColor(1, 1, 0)

							sep.strokeWidth = 4
						end
					else
						node.m_text = text
					end

					--
					local qmark = display.newText(self.help_group, "?", node.x, node.y, native.systemFontBold, layout.ResolveY("6.25%"))

					x = x + dw
				end
			end
		end

		help.GetHelp(on_help)
		grid.GetHelp(on_help)
		help.GetHelp(on_help, "Common")
	end
end

Overlay:addEventListener("show")

--
function Overlay:hide (event)
	if event.phase == "did" then
		for i = self.help_group.numChildren, 1, -1 do
			self.help_group:remove(i)
		end
	end
end

Overlay:addEventListener("hide")

return Overlay