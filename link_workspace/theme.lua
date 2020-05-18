--- The "theme" of the link system, i.e. various dimensions, offsets, strings, etc. whose
-- specific values are incidental to its correctness.

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
local color = require("solar2d_ui.utils.color")
local layout = require("solar2d_ui.utils.layout")

-- Corona globals --
local display = display
local easing = easing
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
function M.AboutOffset ()
	return -10
end

--- DOCME
function M.AboutTextParams ()
	return native.systemFont, 15
end

--- DOCME
function M.AttachmentArrayIndexString (index)
	return ("#%i"):format(index)
end

--- DOCME
function M.AttachmentArrayTextParams ()
	return native.systemFontBold, 10
end

--- DOCME
function M.AttachmentBoxSeparationOffset ()
	return 10
end

--- DOCME
function M.AttachmentBoxSize (w, h)
	return w + 25, h + 15
end

--- DOCME
function M.AttachmentNodeAlpha ()
	return .025
end

--- DOCME
function M.AttachmentRowWidth (w, style)
	return w + (style ~= "array" and 25 or 0)
end

--- DOCME
function M.AttachmentTextEditFont ()
	return "PeacerfulDay"
end

--- DOCME
function M.AttachmentTextEditSize ()
	return layout.ResolveY("3%")
end

--- DOCME
function M.BlockAttachmentBoxSeparationOffset ()
	return 7
end

--- DOCME
function M.Box (group, w, h)
	local box = display.newRoundedRect(group, 0, 0, w, h, 12)

	box:setFillColor(.375, .675)
	box:setStrokeColor(.125)

	box.strokeWidth = 2

	return box
end

--- DOCME
function M.BoxLineSpacing ()
	return 5
end

--- DOCME
function M.BoxMargins ()
	return 10, 30
end

--- DOCME
function M.BoxNameVerticalOffset ()
	return 10
end

--- DOCME
function M.BoxSeparationOffset ()
	return 5
end

--- DOCME
function M.BoxNameText (group, name)
	local ntext = display.newText(group, name, 0, 0, native.systemFont, 12)

	ntext:setFillColor(0)

	return ntext
end

--- DOCME
function M.BoxSize (w, h)
	return w + 35, h + 30
end

--- DOCME
function M.ChoiceDefaultString ()
	return "Choice:" -- consider: localization...
end

--- DOCME
function M.ChoiceTextParams ()
	return native.systemFont, 15
end

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
function M.EmphasizeCanLink (params)
	params.iterations, params.time, params.transition = 0, 1250, easing.continuousLoop
	
	return 1, 0, 1
end

--- DOCME
function M.EmphasizeDefault (_)
	return .2, .3, .2
end

--- DOCME
function M.EmphasizeNotExportToImport (_)
	return .25
end

--- DOCME
function M.EmphasizeOwner (_)
	return 0
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
function M.ItemBoxDragger (group, ibox)
	local dragger = display.newRect(group, 0, 0, ibox.width, ibox.height)

	dragger:setFillColor(0, 0)
	dragger:setStrokeColor(0, .9, 0)

	dragger.strokeWidth = 2
	dragger.isVisible = false

	return dragger
end

--- DOCME
function M.LinkInfoTextParams (font, size)
	font = font or native.systemFont

	return font == "bold" and native.systemFontBold or font, size or 12
end

--- DOCME
function M.ListboxOpts ()
	return { width = "8%", height = "5%", text_rect_height = "3%", text_size = "2.25%" }
end

--- DOCME
function M.MakeRowSize ()
	return "4.25%", "4%"
end

--- DOCME
function M.MakeRowText ()
	return "+"
end

--- DOCME
function M.Node (group)
	local node = display.newCircle(group, 0, 0, 5)

	node.strokeWidth = 1

	return node
end

return M