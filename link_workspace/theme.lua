--- Operations on segments.

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
local random = math.random

-- Modules --
local color = require("corona_ui.utils.color")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

--
--
--

color.RegisterColor("actions", "red")
color.RegisterColor("events", "blue")
color.RegisterColor("props", "green")
color.RegisterColor("unary_action", { r = .2, g = .7, b = .2 })

--- DOCME
function M.DeleteButton (group, ibox)
	local delete = display.newCircle(group, 0, ibox.y, 7)

	delete:setFillColor(.9, 0, 0)
	delete:setStrokeColor(.3, 0, 0)

	delete.alpha = .5
	delete.strokeWidth = 2

	return delete
end

--- DOCME
function M.ItemBoxDragger (group, ibox)
	local dragger = display.newRect(group, 0, 0, ibox.width, ibox.height)

	dragger:setFillColor(0, 0)
	dragger:setStrokeColor(0, .9, 0)

	dragger.strokeWidth = 2
	dragger.isVisible = false

	return dragger
end

--- DOCME
function M.ItemBox (group, x, w, set_style)
	local box = display.newRect(group, x, 0, w, set_style and 35 or 15)

	box:setFillColor(.4)
	box:setStrokeColor(random(), random(), random())

	box.strokeWidth = 2

	return box
end

--- DOCME
function M.Link (group)
	local link = display.newCircle(group, 0, 0, 5)

	link.strokeWidth = 1

	return link
end

--- DOCME
function M.LinkInfoTextParams (font, size)
	font = font or native.systemFont

	return font == "bold" and native.systemFontBold or font, size or 12
end

return M