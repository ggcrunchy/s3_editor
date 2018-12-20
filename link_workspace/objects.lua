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
local assert = assert
local pairs = pairs

-- Unique member keys --
local _count = {}
local _boxes = {}
local _new = {}
local _removed = {}

--
--
--

--- DOCME
function M:AssignObject (id)
	local boxes, new = self[_boxes] or {}, self[_new] or { [_count] = 0 }

	assert(not boxes[id], "Object already assigned")

	local pos = new[_count] + 1

	boxes[id], new[pos] = "pending", id -- exists but no box yet (might already have links, though)
	self[_boxes], self[_new], new[_count] = boxes, new, pos
end

--- DOCME
function M:GetAssociatedBox (id)
	local boxes = self[_boxes]
	local box = boxes and boxes[id]

	return box ~= "pending" and box or nil
end

--- DOCME
function M:GetAssociatedID (box)
	local boxes, id = self[_boxes]

	if boxes and box ~= "pending" then
		for k, v in pairs(boxes) do
			if v == box then
				id = k

				break
			end
		end
	end

	return id
end

--
local function RemoveAttachment (LS, sbox) -- TODO: at the moment, assumes template
											-- but will need to accommodate blocks too
	local linker, nodes = LS:GetLinker(), sbox:GetLinksGroup()

	for i = 1, nodes.numChildren do
		local gend = nodes[i]:GetName()

		linker:RemoveGeneratedName(nodes[i]:GetID(), gend)
		linker:SetLabel(gend, nil)
	end

	LS:RemoveBox(sbox)
end

local function RemoveDeadObjects (LS)
	local removed = LS[_removed]

	if removed then
		for i = 1, removed[_count] do
			local box = removed[i]

			if box ~= "pending" then
				LS:RemoveKnotList(box.m_knot_list_index)

				for _, abox in box:Attachments() do
					RemoveAttachment(LS, abox)
				end

				LS:RemoveBox(box)
			end
		end

		removed[_count] = 0
	end
end

local function AddNewObjects (LS)
	local boxes, new = LS[_boxes], LS[_new] -- n.b. if new exists, so does boxes

	for i = 1, new and new[_count] or 0 do
		local id = new[i]

		if boxes[id] == "pending" then
			boxes[id] = LS:AddPrimaryBox(ItemGroup, id) -- TODO!
		end
	end
end

local function MakeConnections (LS)
	local new = LS[_new]

	if new then
		for i = 1, new[_count] do
			LS:ConnectObject(new[i])
		end

		new[_count] = 0
	end

	LS:FinishConnecting()
end

--- DOCME
function M:Refresh ()
	RemoveDeadObjects(self)
	AddNewObjects(self)
	MakeConnections(self)
end

--- DOCME
function M:RemoveObject (id)
	local boxes, removed = self[_boxes], self[_removed] or { [_count] = 0 }
	local box, pos = assert(boxes and boxes[id], "Object not present"), removed[_count] + 1

	removed[pos], boxes[id] = box
	self[_removed], removed[_count] = removed, pos

	self:GetLinker():RemoveGeneratedName(id, "all")
	-- ^^^ TODO: cache?
end

function M:SetObjectPositions ()
	local linker = self:GetLinker()

	for id, box in pairs(self[_boxes]) do
		if box ~= "pending" then
			local positions = {}

			positions[1], positions[2] = box.parent.x, box.parent.y

			for name, abox in box:Attachments() do
				positions[#positions + 1] = name
				positions[#positions + 1] = abox.parent.x
				positions[#positions + 1] = abox.parent.y
			end

			linker:SetPositions(id, positions)
		end
	end
end

return M