--- Grid logic shared among various editor views.

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
local ceil = math.ceil
local max = math.max
local pairs = pairs

-- Modules --
local common = require("s3_editor.Common")
local grid2D = require("corona_ui.widgets.grid")
local strings = require("tektite_core.var.strings")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

-- --
local Grid

-- --
local Offset

-- --
local Targets

--- Cleans up various state used by editor grid operations.
function M.CleanUp ()
	Grid, Offset, Targets = nil
end

-- Number of columns and rows shown in the grid (maximum) and used as baseline for metrics --
local ColBase, RowBase = 9, 9

--
local function GetCellDims ()
	local gw, gh = display.contentWidth, display.contentHeight - common.GetTopHeight()

	return gw / ColBase, gh / RowBase
end

-- Should multiple layers be shown? --
local DoMultipleLayers

-- One-shot iterator (no-op if value is absent)
local function Once (v, i)
	if v ~= nil and i == nil then
		return v
	end
end

-- Conditional (one- or multi-shot) iterator
local function Iter (v)
	if DoMultipleLayers then
		return pairs(Targets)
	else
		return Once, v
	end
end

-- Column and row of upper-left cell --
local Col, Row

-- How many columns and rows are viewable on the grid? --
local VCols, VRows

--
local function GridRect ()
	local cw, ch = GetCellDims()

	return ceil(cw * VCols), ceil(ch * VRows)
end

--- Initializes various state used by editor grid operations.
-- @pgroup view Map editor scene view.
function M.Init (view)
	Grid, Targets, Col, Row, VCols, VRows = {}, {}, 0, 0, common.GetDims()

	-- Consolidate grid and related interface elements into a group.
	Grid.group = display.newGroup()

	local gw, gh = GridRect()
	local _, drag = common.NewScreenSizeContainer(view, Grid.group, {
		dx = max(0, gw - display.contentWidth), dy = max(0, gh - (display.contentHeight - common.GetTopHeight()))
	})

	Grid.drag, drag.isHitTestable = drag, false

	-- Start out in the hidden state.
	M.Show(false)
end

--- DOCME
function M.NewGrid ()
	local gw, gh = GridRect()
	local grid = grid2D.Grid_XY(Grid.group, 0, 0, gw, gh, VCols, VRows)

	grid:ShowBack(false)

	grid.isVisible = false

	Targets[grid] = true

	return grid
end

--- DOCME
function M.SetDraggable (draggable)
	Grid.drag.isHitTestable = not not draggable
end

---DOCME
-- @pgroup target
function M.Show (target)
	local show = not not target

	--
	if show then
		for grid in Iter(target) do
			grid:ShowLines(grid == target)

			if grid == target then
				grid.alpha = 1
			else
				grid.alpha = .75

				grid:toBack()
			end

			grid.isVisible = true
		end

	--
	else
		for grid in pairs(Targets) do
			grid.isVisible = false
		end
	end

	--
	Grid.active = target
	Grid.group.isVisible = show
end

--- Utility.
-- @bool show Enable showing multiple layers?
function M.ShowMultipleLayers (show)
	DoMultipleLayers = not not show
end

--
local function DefShowOrHide (item, show)
	item.isVisible = show
end

---DOCME
-- @ptable items
-- @callable func
function M.ShowOrHide (items, func)
	do return end
	func = func or DefShowOrHide

	local redge, bedge = Col + VCols, Row + VRows

	for k, v in pairs(items) do
		local col, row = strings.KeyToPair(k)

		func(v, col > Col and col <= redge and row > Row and row <= bedge)
	end
end

--- DOCME
function M.ShowPick (pick, col, row, show)
	if pick and pick.m_col == col and pick.m_row == row then
		pick.isVisible = show
	end
end

--- DOCME
function M.UpdatePick (group, pick, col, row, x, y, w, h)
	if not pick then
		pick = display.newRect(group, 0, 0, w, h)

		pick:setFillColor(1, 0, 0, .25)
	end

	pick:toBack()

	pick.x, pick.y = x, y

	pick.m_col = col
	pick.m_row = row

	return pick
end

return M