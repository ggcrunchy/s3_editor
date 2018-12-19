--- Management of link view objects.

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

-- Exports --
local M = {}

-- Standard library imports --
local pairs = pairs
local ipairs = ipairs
local sort = table.sort

-- Modules --
local common = require("s3_editor.Common")

-- Corona globals --
local display = display

-- Unique member keys --
local _index = {}
local _tagged = {}
local _to_remove = {}
local _to_sort = {}

--
--
--

local Index, Tagged, ToRemove, ToSort

--- DOCME
function M.AssociateBoxAndObject (object, box, name)
	-- ^^^ TODO: these should both be ids, I think, for undo / redo
	Tagged[object], object.m_link_index = { m_box = box, m_name = name }
end

--- DOCME
function M.GetBox (object)
	return Tagged[object].m_box
end

local function AuxRemovingIter (t, n)
	while n > 0 do
		local object = t[n]

		n, t[n] = n - 1

		if object then
			return n, object
		end
	end
end

local function SortByIndex (a, b)
	return a.m_link_index < b.m_link_index
end

--- DOCME
function M:IterateNewObjects (how)
	local to_sort = self[_to_sort]

	if how == "remove" then
		return AuxRemovingIter, to_sort, #to_sort
	else
		sort(to_sort, SortByIndex)

		return ipairs(to_sort)
	end
end

--- DOCME
function M:IterateRemovedObjects ()
	local to_remove = self[_to_remove]

	return AuxRemovingIter, to_remove, #to_remove
end

local function OnAssign (object)
	Tagged[object] = false -- exists but no box yet (might already have links, though)

	object.m_link_index, Index = Index, Index + 1
end

local function OnRemove (object)
	ToRemove[#ToRemove + 1], Tagged[object] = Tagged[object]

	common.RemoveInstance(object, "all")
end

--- DOCME
function M.Load ()
	Index, Tagged, ToRemove, ToSort = 1, {}, {}, {}

	local links = common.GetLinks()

	links:SetAssignFunc(OnAssign)
	links:SetRemoveFunc(OnRemove)
end

--- DOCME
function M:Refresh ()
	self[_index] = 1

	local to_sort = self[_to_sort]

	for object, state in pairs(Tagged) do
		if not state then
			to_sort[#to_sort + 1] = object
		end
	end

--[[
	local name = common.GetValuesFromRep(object).name

	if state.m_name.text ~= name then
		state.m_name.text = name
		-- TODO: might need resizing :/
		-- TODO: probably needs a Runtime event
	end
]]
end

--- DOCME
function M.Unload ()
	Tagged, ToRemove, ToSort = nil
end

-- Listen to events.
Runtime:addEventListener("set_object_positions", function()
	for object, state in pairs(Tagged) do
		if state then
			local box, positions = state.m_box, {}

			positions[1], positions[2] = box.parent.x, box.parent.y

			for name, abox in box:Attachments() do
				positions[#positions + 1] = name
				positions[#positions + 1] = abox.parent.x
				positions[#positions + 1] = abox.parent.y
			end

			common.SetPositions(object, positions) -- TODO
		end
	end
end)

return M