--- Management of link view attachments.

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
local array_index = require("tektite_core.array.index")
local utils = require("s3_editor.link_workspace.utils")

-- Cached module references --
local _RemoveRange_

-- Exports --
local M = {}

--
--
--

function M.RemoveRange (list, last, n)
	for _ = 1, n do
		list:remove(last)

		last = last - 1
	end
end

local function Shift (linker, items, shift, a, b, is_array)
	local delta = shift > 0 and 1 or -1

	for i = a, b, delta do
		local gend = is_array and items[i].m_generated_name

		if gend then
			linker:SetLabel(gend, linker:GetLabel(gend) + delta)
		end

		items[i].y = items[i + shift].y
	end
end

function M.RemoveRow (linker, list, row, n, is_array)
	local last = row * n

	Shift(linker, list, -n, list.numChildren, last + 1, is_array)
	_RemoveRange_(list, last, n)
end

--- DOCME
local function GetFromItemInfo (linker, items, fi, ti, n, is_array)
	for i = 0, n - 1 do
		local from_gend = is_array and items[ti - i].m_generated_name

		if from_gend then
			items[fi - i].m_old_index = linker:GetLabel(from_gend)
		end

		items[fi - i].m_y = items[ti - i].y
	end
end

--- DOCME
local function SetToItemInfo (linker, items, _, ti, n)
	for i = 0, n - 1 do
		local item = items[ti - i]

		if item.m_old_index then
			linker:SetLabel(item.m_generated_name, item.m_old_index)
		end

		item.y, item.m_old_index, item.m_y = item.m_y
	end
end

local function AuxMoveRow (linker, items, stash, fi, ti, n, is_array)
	GetFromItemInfo(linker, items, fi, ti, n, is_array)

	local tpos = ti - n + 1

	if fi < ti then
		Shift(linker, items, -n, ti, fi + 1, is_array)
	else
		Shift(linker, items, n, tpos, fi - n, is_array)
	end

	for i = 0, n - 1 do -- to avoid having to reason about how insert() works with elements
                        -- already in the group, temporarily put them somewhere else, in
                        -- reverse order...
		stash:insert(items[fi - i])
	end

	for i = 1, n do -- ...then stitch them back in where they belong
		items:insert(tpos, stash[stash.numChildren - n + i])
	end

	SetToItemInfo(linker, items, fi, ti, n)
end

--- DOCME
function M.MoveRow (items, nodes, from, to)
	if from ~= to then
		local box = items.parent:FindBox()
		local n = items.numChildren / nodes.numChildren -- only one node per row, but maybe multiple items
		local fi, ti = from * n, to * n
		local linker = utils.FindLinkScene(items):GetLinker()

		AuxMoveRow(linker, items, nodes, fi, ti, n, box.m_style == "array")
		AuxMoveRow(linker, nodes, items, from, to, 1)
	end
end

--- DOCME
function M.FindRow (drag_box, box, nodes)
	local row = array_index.FitToSlot(drag_box.y, box.y + box.height / 2, drag_box.height)

	return (row >= 1 and row <= nodes.numChildren) and row
end

_RemoveRange_ = M.RemoveRange

return M