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
local ipairs = ipairs
local max = math.max
local pairs = pairs
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local color = require("corona_ui.utils.color")
local common = require("s3_editor.Common")
local meta = require("tektite_core.table.meta")
local theme = require("s3_editor.link_workspace.theme")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display

-- Unique member keys --
local _id = {}
local _name = {}

-- Exports --
local M = {}

--
--
--

local BoxID, LastSpot = 0

local function FindFreeSpot (x, how)
	local sx, sy

	if x then
		LastSpot, sx, sy = cells.FindFreeCell_LeftOrRight(LastSpot, x, how)
	else
		LastSpot, sx, sy = cells.FindFreeCell(LastSpot)
	end

	return sx, sy
end

local DragTouch = touch.DragParentTouch{
	clamp = "max", offset_by_object = true, -- TODO: not sure max is worth keeping
											-- or maybe just make it quite large
											-- offset might be irrelevant if not using cells
--[[
	on_began = function(_, box)
		cells.RemoveFromCell(ItemGroup, box)
	end,

	on_ended = function(_, box)
		cells.AddToCell(ItemGroup, box)
	end]]
}

local function FindBox (bgroup)
	for i = 1, bgroup.numChildren do
		local elem = bgroup[i]

		if elem.m_knot_list_index then -- reasonably box-specific
			return elem
		end
	end
end

local function GetID (box)
	return box.m_id
end

local KnotListIndex = 0

function M:AddBox (group, w, h)
	local box = theme.Box(group, w, h)

	box_layout.CommitLeftAndRightGroups(box, theme.BoxMargins())

	box:addEventListener("touch", DragTouch)
	box:toBack() -- put behind items et al.

	group.FindBox = FindBox

	box.m_id, BoxID = BoxID, BoxID + 1
	box.m_knot_list_index = KnotListIndex

	box.GetID = GetID

	return box
end

local EntryInfo = { "about", "font", "size", "color", "r", "g", "b" }

local function PopulateEntryFromInfo (entry, text, info)
	if entry then
		info = info or LinkInfoEx -- LinkInfoEx is an array, so accesses will yield nil

		entry.text = text

		for _, name in ipairs(EntryInfo) do
			entry[name] = info[name]
		end
	else
		return info -- N.B. at the moment we care about this when not populating the entry
	end
end

local function AuxSublinkInfo (info, name)
	local iinfo = info and info[name]
	local itype, is_source = iinfo and type(iinfo), tag_db ~= nil and tag_db:ImplementedBySublink(tag, name, "event_source")
-- ^^^ TODO: what would be the equivalent here? something like finding that it's an export
-- and ImplementsValue()?
	if itype == "table" then
		if iinfo.is_source ~= nil then
			is_source = iinfo.is_source
		end

		return is_source, iinfo.friendly_name, iinfo
	else
		return is_source, itype == "string" and iinfo or nil
	end
end

local function SublinkInfo (info--[[, tag_db, tag]], name, entry)
	local is_source, _, iinfo = AuxSublinkInfo(info, name)

	return is_source, iinfo
end

local function SublinkInfo_Entry (info--[[, tag_db, tag]], name, entry)
	local is_source, text, iinfo = AuxSublinkInfo(info, name)

	PopulateEntryFromInfo(entry, text, iinfo)

	return is_source
end

--
local function AddAttachments (LS, group, id, info)--, tag_db, tag)
	local node_pattern, list, groups = LS:GetNodePattern(id)

	for name in node_pattern:IterTemplateNodes() do
		list = list or {}

		local is_source, iinfo = SublinkInfo(info--[[, tag_db, tag]], name)
		local gname = iinfo and iinfo.group

		if gname then
			groups, list[gname] = groups or {}, false

			local ginfo = groups[gname] or {}

			groups[gname], ginfo[name] = ginfo, iinfo.friendly_name or name
		else
			list[#list + 1] = LS:AttachmentBox(group, id, name, is_source, iinfo and iinfo.is_set)
			list[name] = #list
		end
	end

	if groups then
		for gname, index in pairs(list) do
			if not index then
				local ginfo, is_source, iinfo = groups[gname], SublinkInfo(info--[[, nil, nil]], gname)

				ginfo.add_choices = iinfo.add_choices
				ginfo.choice_text = iinfo.choice_text
				ginfo.get_text = iinfo.get_text

				list[#list + 1] = LS:AttachmentBox(group, id, ginfo, is_source, "mixed")
				list[gname] = #list
			end
		end
	end

	return list
end

local function AddBoxNameText (LS, group, id)
	local linker = LS:GetLinker()
	local name = linker:GetValuesFromIdentifier(id).name

	return theme.NameText(group, name)
end

local function AssignPositions (primary, alist, positions)
	local x, y

	if positions then
		x, y = positions[1], positions[2]
	else
		x, y = FindFreeSpot()
	end

	cells.PutBoxAt(primary, x, y, positions and "raw")

	if positions and alist then
		for i = 3, #positions, 3 do
			local aindex = alist[positions[i]]

			cells.PutBoxAt(alist[aindex], positions[i + 1], positions[i + 2], "raw")
		end
	else
		for i = 1, #(alist or "") do
			local abox = alist[i]

			cells.PutBoxAt(abox, FindFreeSpot(x, abox.m_is_export and "right_of" or "left_of"))	
		end
	end
end

local function InfoEntry (index)
	local entry = LinkInfoEx[index]

	if not entry then
		entry = {}
		LinkInfoEx[index] = entry
	end

	return entry
end

local Indices, Order -- TODO: members

local function PutItemsInPlace (lg, n)
	if lg then
		Indices, Order = Indices or {}, Order or {}

		for i = 1, n do
			local li = LinkInfoEx[i]

			Indices[i], Order[li.name], LinkInfoEx[i] = li.name, li, false
		end

		local li, is_source

		for i, ginfo in ipairs(lg) do
			if Order[ginfo] then
				li, Order[ginfo] = Order[ginfo]

				if is_source ~= nil then -- otherwise use own value
					li.is_source = is_source
				end
			else
				li, n, is_source = InfoEntry(n + 1), n + 1
				Indices[n] = false -- ensure empty

				for k in pairs(li) do
					li[k] = nil
				end

				if type(ginfo) == "table" then
					if ginfo.is_source ~= nil then
						is_source = ginfo.is_source
					end

					PopulateEntryFromInfo(li, ginfo.text, ginfo)
				else
					PopulateEntryFromInfo(li, ginfo)
				end

				li.is_source = is_source ~= nil and is_source -- false or is_source
			end

			LinkInfoEx[i] = li
		end

		-- Stitch any outstanding entries back in at the end in whatever order pairs() gives
		-- us. These will overwrite any new entries from n + 1 to n + X, so they will in fact
		-- only be present earlier in the list where they were added. For convenience, any
		-- such entries are added according to their original relative order. 
		local ii, index = 1, #lg

		repeat
			local sub = Indices[ii]
			local info = Order[sub] -- nil if removed or sub is falsy

			if info then
				LinkInfoEx[index + 1], index, Order[sub] = info, index + 1
			end

			ii = ii + 1
		until not sub
	end

	return n
end

local function GroupLinkInfo (info--[[, tag_db, tag]], alist)
	local n, lg, seen = 0, info and common.GetLinkGrouping(tag)

	for _, name in tag_db:Sublinks(tag, "no_instances") do -- TODO: just iterate nodes?
		local ok--[[, db]], _, iinfo = true--[[, tag_db]], SublinkInfo(info--[[, tag_db, tag]], name)

		if iinfo and iinfo.group then
			name = iinfo.group
			ok, seen, db = not adaptive.InSet(seen, name), adaptive.AddToSet(seen, name)
		end

		if ok then
			n = n + 1

			local li = InfoEntry(n)

			li.is_source = SublinkInfo_Entry(info--[[, db, tag]], name, li)
			-- ^^^ TODO: can this just use stuff from the call above and use the PopulateXX instead?
			li.aindex, li.name, li.want_link = alist and alist[name], name, true
		end
	end

	return PutItemsInPlace(lg, n)
end

local function RowItems (node, stext, about)
	if node then
		return node, stext, about
	else
		return stext, about
	end
end

local function ItemNameText (group, li)
	local font, size = theme.LinkInfoTextParams(li.font, li.size)
	local str = display.newText(group, li.text or li.name, 0, 0, font, size)

	if li.color then
		str:setFillColor(color.GetColor(li.color))
	elseif li.r or li.g or li.b then
		str:setFillColor(li.r or 0, li.g or 0, li.b or 0)
	end

	return str
end

local function DoLinkInfo (LS, bgroup, object, li, alist)
	local cur = box_layout.ChooseLeftOrRightGroup(bgroup, li.is_source)
	local node, iname = li.want_link and theme.Node(cur), ItemNameText(cur, li)

	if li.about then
		-- hook up some touch listener, change appearance
		-- ^^ Maybe add a question mark-type thing
	end

	--
	local lo, ro = box_layout.Arrange(li.is_source, 5, RowItems(node, iname, li.about)) -- TODO: theme

	--
	if li.aindex then
		LS:LinkAttachment(node, alist[li.aindex])
	elseif node then
		LS:IntegrateNode(node, object, li.name, li.is_source)
	end

	--
	box_layout.AddLine(cur, lo, ro, 5, node) -- TODO: theme
end

--- DOCME
function M:AddPrimaryBox (group--[[, tag_db, tag]], id)
	local info, bgroup = common.AttachLinkInfo(id, nil), display.newGroup()
-- ^^ TODO
	group:insert(bgroup)

	--
	local alist = AddAttachments(self, group, id, info)--, tag_db, tag)

	for i = 1, GroupLinkInfo(info--[[, tag_db, tag]], alist) do
		DoLinkInfo(self, bgroup, id, LinkInfoEx[i], alist)
	end

	--
	local w, h = box_layout.GetSize()
	local ntext = AddBoxNameText(self, bgroup, id)
	local box = self:AddBox(bgroup, max(w, ntext.width) + 35, h + 30) -- TODO: theme

	self:AddKnotList(KnotListIndex)

	box.m_attachments = alist

	--
	KnotListIndex = KnotListIndex + 1

	ntext.y = box_layout.GetY1(box) + 10 -- TODO: theme

	local linker = self:GetLinker()

	AssignPositions(box, alist, linker:GetPositions(id))

	return box, ntext
end

local Node = {}

Node.__index = Node

--- DOCME
function Node:GetID ()
	return self[_id]
end

--- DOCME
function Node:GetName ()
	return self[_name]
end

function M:IntegrateNode (node, id, name, is_export, index)
	self:AddNode(index or KnotListIndex, not is_export, node)

	node[_id], node[_name] = id, name

	meta.Augment(node, Node)
end

--- DOCME
function M:RemoveBox (box)
	cells.RemoveFromCell(ItemGroup, box)

	box.parent:removeSelf()
end

return M