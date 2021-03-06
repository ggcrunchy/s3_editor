--- Management of layouts for link view boxes.

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
local min = math.min

-- Modules --
local layout = require("solar2d_ui.utils.layout")

-- Solar2D globals --
local display = display

-- Cached module references --
local _Arrange_
local _GetLineWidth_
local _GetY1_
local _LeftAndRight_

-- Unique member keys --
local _left_and_right_group = {}
local _list1 = {}
local _list2 = {}

-- Exports --
local M = {}

--
--
--

local function FindBottom (group, how)
	local y2, n, bobj = 0, group.numChildren
	local line = n > 0 and group[n].m_line

	for i = n, 1, -1 do
		local object = group[i]

		if object.m_line ~= line then
			break
		else
			local oy = object.y + object.height / 2

			if oy > y2 then
				y2, bobj = oy, object
			end
		end
	end

	return how == "want_object" and bobj or y2
end

--- DOCME
function M.AddLine (group, left_object, right_object, spacing, lowest)
	local w, line, n = _GetLineWidth_(left_object, right_object), (group.m_line or 0) + 1, group.numChildren

	group.m_w = max(group.m_w or 0, w)

	for i = (group.m_last_count or 0) + 1, group.numChildren do
		local object = group[i]

		if line > 1 then
			layout.PutBelow(object, group.m_prev, spacing)
		else
			group.m_y1 = min(group.m_y1 or 0, _GetY1_(object))
		end
	end

	group.m_last_count, group.m_line = n, line
	group.m_prev = lowest or FindBottom(group, "want_object")
end

--- DOCME
function M.Arrange (side, offset, a, b, c, d, e, f)
	local method

	if not b then
		offset = offset + a.width / 2
		a.x = a.x + (side == "rhs" and -offset or offset)
	elseif side == "rhs" then
		method, offset = layout.PutLeftOf, -offset
	else
		method = layout.PutRightOf
	end

	if b then
		method(b, a, offset)
	end

	if c then
		method(c, b, offset)
	end

	if d then
		method(d, c, offset)
	end

	if e then
		method(e, d, offset)
	end

	if f then
		method(f, e, offset)
	end

	return _LeftAndRight_(side, a, b, c, d, e, f)
end

local LeftAndRightGroup

--- DOCME
function M.ChooseLeftOrRightGroup (bgroup, side)
	if not LeftAndRightGroup[side] then
		LeftAndRightGroup[side] = display.newGroup()

		bgroup:insert(LeftAndRightGroup[side])
	end

	return LeftAndRightGroup[side]
end

--[[
TODO: might be superfluous

local function Align (group, is_rgroup)
	local w = group.m_w

	for i = 1, group.numChildren do
		local object = group[i]
		local dx = w - object.m_w

		if is_rgroup then
			object.x = object.x + dx
		else
			object.x = object.x - dx
		end
	end
end
]]

--- DOCME
function M.CommitLeftAndRightGroups (box, hmargin, vmargin)
	local lgroup, rgroup = LeftAndRightGroup.lhs, LeftAndRightGroup.rhs
	local hw, y1 = box.width / 2 - hmargin, _GetY1_(box) + vmargin
--[[
	TODO: unnecessary?

	Align(lgroup, false)
	Align(lgroup, true)
]]
	if lgroup then
		box.m_lgroup, lgroup.x, lgroup.y = lgroup, box.x - hw, y1
	end

	if rgroup then
		box.m_rgroup, rgroup.x, rgroup.y = rgroup, box.x + hw, y1
		rgroup.anchorX = 1
	end

	LeftAndRightGroup.lhs, LeftAndRightGroup.rhs = nil
end

--- DOCME
function M.GetLineWidth (left_object, right_object, how)
	local left_of, right_of = layout.LeftOf(left_object), layout.RightOf(right_object)

	return right_of - left_of, how == "want_middle" and (left_of + right_of) / 2
end

--- DOCME
function M.GetSize ()
	local lgroup, rgroup = LeftAndRightGroup.lhs, LeftAndRightGroup.rhs
	local w, y1, y2 = lgroup and lgroup.m_w or 0, 0, 0

	if lgroup and rgroup then
		w = w + rgroup.m_w
		y1 = min(lgroup.m_y1, rgroup.m_y1)
		y2 = max(FindBottom(lgroup), FindBottom(rgroup))
	elseif lgroup then
		y1, y2 = lgroup.m_y1, FindBottom(lgroup)
	elseif rgroup then
		w, y1, y2 = rgroup.m_w, rgroup.m_y1, FindBottom(rgroup)
	end

	return w, y2 - y1
end

--- DOCME
function M.GetY1 (object)
	return object.y - object.height / 2
end

local function AuxGroups (groups, index)
	index = index + 1

	local cur = groups[index]

	if cur then
		return index, cur
	end
end

local List1, List2

--- DOCME
function M.IterateGroupsOfNodes (box)
	List1, List2 = List2, List1

	local glist = List1

	for i = #glist, 1, -1 do
		glist[i] = nil
	end

	glist[#glist + 1] = box.m_lgroup
	glist[#glist + 1] = box.m_rgroup

	for _, abox in box:Attachments() do
		glist[#glist + 1] = abox:NodesGroup()
	end

	return AuxGroups, glist, 0
end

--- DOCME
function M.LeftAndRight (side, a, b, c, d, e, f)
	local last = f or e or d or c or b or a

	if side == "rhs" then
		return last, a
	else
		return a, last
	end
end

--- DOCME
function M.Load ()
	LeftAndRightGroup, List1, List2 = {}, {}, {}
end

--- DOCME
function M.Unload ()
	LeftAndRightGroup, List1, List2 = nil
end

--- DOCME
function M.UpdateWidth (box, w)
	-- TODO!
	-- basically: names can change, potentially overflowing the box...
	-- but could later shorten, too
end

-- TODO: could actually clean some of this up by a dynamic resize, but difficult if box in
-- agroup... but complicates some of how things are being done, e.g. looking up parent
-- on the other hand, maybe could keep around a temporary group for this very purpose,
-- and hoist in and out?

_Arrange_ = M.Arrange
_GetLineWidth_ = M.GetLineWidth
_GetY1_ = M.GetY1
_LeftAndRight_ = M.LeftAndRight

return M