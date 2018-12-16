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
local theme = require("s3_editor.link_workspace.theme")

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

function M:AddBox (group, w, h)
	local box = cells.NewBox(group, w, h, 12) -- TODO: theme

	box_layout.CommitLeftAndRightGroups(box, 10, 30)

	box:addEventListener("touch", DragTouch)
	box:setFillColor(.375, .675)
	box:setStrokeColor(.125)
	box:toBack()

	box.strokeWidth = 2

	box.m_id, BoxID = BoxID, BoxID + 1
	box.m_knot_list_index = KnotListIndex

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

local function SublinkInfo (info, tag_db, tag, sub, entry)
	local iinfo = info and info[sub]
	local itype, is_source = iinfo and type(iinfo), tag_db ~= nil and tag_db:ImplementedBySublink(tag, sub, "event_source")

	if itype == "table" then
		if iinfo.is_source ~= nil then
			is_source = iinfo.is_source
		end

		return is_source, PopulateEntryFromInfo(entry, iinfo.friendly_name, iinfo)
	else
		return is_source, PopulateEntryFromInfo(entry, itype == "string" and iinfo or nil)
	end
end

--
local function AddAttachments (group, object, info, tag_db, tag)
	local list, groups

	for _, sub in tag_db:Sublinks(tag, "templates") do
		list = list or {}

		local is_source, iinfo = SublinkInfo(info, tag_db, tag, sub)
		local gname = iinfo and iinfo.group

		if gname then
			groups, list[gname] = groups or {}, false

			local ginfo = groups[gname] or {}

			groups[gname], ginfo[sub] = ginfo, iinfo.friendly_name or sub
		else
			list[#list + 1] = self:AttachmentBox(group, object, tag_db, tag, sub, is_source, iinfo and iinfo.is_set)
			list[sub] = #list
		end
	end

	if groups then
		for gname, index in pairs(list) do
			if not index then
				local ginfo, is_source, iinfo = groups[gname], SublinkInfo(info, nil, nil, gname)

				ginfo.add_choices = iinfo.add_choices
				ginfo.choice_text = iinfo.choice_text
				ginfo.get_text = iinfo.get_text

				list[#list + 1] = self:AttachmentBox(group, object, tag_db, tag, ginfo, is_source, "mixed")
				list[gname] = #list
			end
		end
	end

	return list
end

local function AddNameText (group, object)
	local name = common.GetValuesFromRep(object).name
	local ntext = display.newText(group, name, 0, 0, native.systemFont, 12) -- TODO: theme

	ntext:setFillColor(0)

	return ntext
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

			cells.PutBoxAt(abox, FindFreeSpot(x, abox.m_is_source and "right_of" or "left_of"))	
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

local Indices, Order

local function PutItemsInPlace (lg, n)
	if lg then
		Indices, Order = Indices or {}, Order or {}

		for i = 1, n do
			local li = LinkInfoEx[i]

			Indices[i], Order[li.sub], LinkInfoEx[i] = li.sub, li, false
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

local function GroupLinkInfo (info, tag_db, tag, alist)
	local n, lg, seen = 0, info and common.GetLinkGrouping(tag)

	for _, sub in tag_db:Sublinks(tag, "no_instances") do
		local ok, db, _, iinfo = true, tag_db, SublinkInfo(info, tag_db, tag, sub)

		if iinfo and iinfo.group then
			sub = iinfo.group
			ok, seen, db = not adaptive.InSet(seen, sub), adaptive.AddToSet(seen, sub)
		end

		if ok then
			n = n + 1

			local li = InfoEntry(n)

			li.is_source = SublinkInfo(info, db, tag, sub, li)
			li.aindex, li.sub, li.want_link = alist and alist[sub], sub, true
		end
	end

	return PutItemsInPlace(lg, n)
end

local function RowItems (link, stext, about)
	if link then
		return link, stext, about
	else
		return stext, about
	end
end

--- DOCME
function M:AddPrimaryBox (group, tag_db, tag, object)
	local info, bgroup = common.AttachLinkInfo(object, nil), display.newGroup()

	group:insert(bgroup)

	--
	local alist = AddAttachments(group, object, info, tag_db, tag)

	for i = 1, GroupLinkInfo(info, tag_db, tag, alist) do
		local li = LinkInfoEx[i]
		local cur = box_layout.ChooseLeftOrRightGroup(bgroup, li.is_source)
		local font, size = theme.LinkInfoTextParams(li.font, li.size)
		local node, stext = li.want_link and theme.Node(cur), display.newText(cur, li.text or li.sub, 0, 0, font, size)

		if li.color then
			stext:setFillColor(color.GetColor(li.color))
		elseif li.r or li.g or li.b then
			stext:setFillColor(li.r or 0, li.g or 0, li.b or 0)
		end

		if li.about then
			-- hook up some touch listener, change appearance
			-- ^^ Maybe add a question mark-type thing
		end

		--
		local lo, ro = box_layout.Arrange(li.is_source, 5, RowItems(node, stext, li.about)) -- TODO: theme

		--
		if li.aindex then
			self:LinkAttachment(node, alist[li.aindex])
		elseif node then
			self:IntegrateNode(node, object, li.sub, li.is_source)
		end

		--
		box_layout.AddLine(cur, lo, ro, 5, node) -- TODO: theme
	end

	--
	local w, h = box_layout.GetSize()
	local ntext = AddNameText(bgroup, object)
	local box = self:AddBox(bgroup, max(w, ntext.width) + 35, h + 30) -- TODO: theme

	self:AddKnotList(KnotListIndex)

	box.m_attachments = alist

	--
	KnotListIndex = KnotListIndex + 1

	ntext.y = box_layout.GetY1(box) + 10 -- TODO: theme

	AssignPositions(box, alist, common.GetPositions(object))

	return box, ntext
end

--- DOCME
function M:RemoveBox (box)
	cells.RemoveFromCell(ItemGroup, box)

	box.parent:removeSelf()
end

return M