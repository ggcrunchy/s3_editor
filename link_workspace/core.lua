--- Link editing.

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

-- Some sort of cloud of groups, probably made on the fly
-- Nodes moved in and out of those as they're moved around (groups will be somewhat generous, accommodate largest size)
-- Lines in separate groups? (Must allow for large distances, in general... but could use some bounding box analysis...)
-- Search feature? (Based on tag, then on list... essentially what's available now)
-- Would the above make LinkGroup obsolete? Would it promote the search box?

-- Standard library imports --
local ipairs = ipairs
local max = math.max
local pairs = pairs
local setmetatable = setmetatable
local sort = table.sort
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local args = require("iterator_ops.args")
local color = require("corona_ui.utils.color")
local common = require("s3_editor.Common")
local editor_strings = require("config.EditorStrings")
local help = require("s3_editor.Help")
local touch = require("corona_ui.utils.touch")

local method_augments = {
	require("s3_editor.link_workspace.attachments"),
	require("s3_editor.link_workspace.box_layout"),
	require("s3_editor.link_workspace.cells"), -- TODO: remove
	require("s3_editor.link_workspace.connections"),
	require("s3_editor.link_workspace.globals"), -- TODO: remove
	require("s3_editor.link_workspace.objects")
	-- TODO: box_factory, theming, etc.
}

-- Corona globals --
local display = display
local easing = easing
local native = native
local system = system
local transition = transition

-- Exports --
local M = {}

--
--
--

local LinkScene = {}

LinkScene.__index = LinkScene

for _, mod in ipairs(method_augments) do
	for k, v in pairs(mod) do
		LinkScene[k] = v
	end
end

-- --
local Group

-- --
local ItemGroup

-- --
local LinkInfoEx

-- --
local Offset

-- Box drag listener --
local DragTouch

--
local FadeParams = {}

local function EmphasizeLinks (item, how, link, source_to_target, not_owner)
	local r, g, b = 1

	if item.m_glowing then
		transition.cancel(item.m_glowing)

		item.m_glowing = nil
	end

	if how == "began" then
		if not not_owner then
			r = 0
		elseif not source_to_target then
			r = .25
		elseif common.GetLinks():CanLink(link.m_obj, item.m_obj, link.m_sub, item.m_sub) then
			FadeParams.iterations, FadeParams.time, FadeParams.transition = 0, 1250, easing.continuousLoop
			r, g, b = 1, 0, 1
		else
			r, g, b = .2, .3, .2
		end
	end

	FadeParams.r, FadeParams.g, FadeParams.b = r, g or r, b or r

	local handle = transition.to(item.fill, FadeParams)

	item.m_glowing = FadeParams.transition and handle or nil
	FadeParams.iterations, FadeParams.time, FadeParams.transition = nil
end

local function SortByID (box1, box2)
	return box1.m_id > box2.m_id
end

local function GatherLinks (items)
	local boxes_seen = items.m_boxes_seen or {}

	cells.GatherVisibleBoxes(Offset.x, Offset.y, boxes_seen)

	sort(boxes_seen, SortByID) -- make links agree with render order

	for _, box in ipairs(boxes_seen) do
		for _, group in box_layout.IterateGroupsOfLinks(box) do
			for i = 1, group.numChildren do
				items[#items + 1] = group[i]
			end
		end
	end

	items.m_boxes_seen = boxes_seen
end

-- --
cells.SetCellFraction(.35)

-- --
local HelpContext

---
-- @pgroup view X
function M.Load (view)
	box_layout.Load()

	--
	Group, ItemGroup, LinkInfoEx, Offset = display.newGroup(), display.newGroup(), {}, {}

	view:insert(Group)

	local link_layer = display.newGroup()
	local cont, drag = common.NewScreenSizeContainer(Group, ItemGroup, { layers = { link_layer }, offset = Offset })

	drag:toBack()

	HelpContext = help.NewContext()

	HelpContext:Add(cont, editor_strings("link"))
	HelpContext:Register()
	HelpContext:Show(false)

	--
	cells.Load(cont)
	objects.Load()

	--
	DragTouch = touch.DragParentTouch{
		clamp = "max", offset_by_object = true,

		on_began = function(_, box)
			cells.RemoveFromCell(ItemGroup, box)
		end,

		on_ended = function(_, box)
			cells.AddToCell(ItemGroup, box)
		end
	}

	--
	connections.Load(link_layer, EmphasizeLinks, GatherLinks)
	globals.Load(view)

	Group.isVisible = false
end

-- --
local KnotListIndex = 0

local function IntegrateLink (link, object, sub, is_source, index)
	connections.AddLink(index or KnotListIndex, not is_source, link)

	link.m_obj, link.m_sub = object, sub
end

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

local function AddBox (group, w, h)
	local box = cells.NewBox(group, w, h, 12)

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

local function Link (group)
	local link = display.newCircle(group, 0, 0, 5)

	link.strokeWidth = 1

	return link
end

color.RegisterColor("actions", "red")
color.RegisterColor("events", "blue")
color.RegisterColor("props", "green")
color.RegisterColor("unary_action", { r = .2, g = .7, b = .2 })

local function PopulateEntryFromInfo (entry, text, info)
	if entry then
		info = info or LinkInfoEx -- LinkInfoEx is an array, so accesses will yield nil

		entry.text = text

		for _, name in args.Args("about", "font", "size", "color", "r", "g", "b") do
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
			list[#list + 1] = attachments.Box(group, object, tag_db, tag, sub, is_source, iinfo and iinfo.is_set)
			list[sub] = #list
		end
	end

	if groups then
		for gname, index in pairs(list) do
			if not index then
				local ginfo, is_source, iinfo = groups[gname], SublinkInfo(info, nil, nil, gname)

				for _, name in args.Args("add_choices", "choice_text", "get_text") do
					ginfo[name] = iinfo[name]
				end

				list[#list + 1] = attachments.Box(group, object, tag_db, tag, ginfo, is_source, "mixed")
				list[gname] = #list
			end
		end
	end

	return list
end

local function AddNameText (group, object)
	local name = common.GetValuesFromRep(object).name
	local ntext = display.newText(group, name, 0, 0, native.systemFont, 12)

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

--
local function AddPrimaryBox (LS, group, tag_db, tag, object)
	local info, bgroup = common.AttachLinkInfo(object, nil), display.newGroup()

	group:insert(bgroup)

	--
	local alist = AddAttachments(group, object, info, tag_db, tag)

	for i = 1, GroupLinkInfo(info, tag_db, tag, alist) do
		local li = LinkInfoEx[i]
		local cur = box_layout.ChooseLeftOrRightGroup(bgroup, li.is_source)
		local font, size = li.font or native.systemFont, li.size or 12

		font = font == "bold" and native.systemFontBold or font

		local link, stext = li.want_link and Link(cur), display.newText(cur, li.text or li.sub, 0, 0, font, size)

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
		local lo, ro = box_layout.Arrange(li.is_source, 5, RowItems(link, stext, li.about))

		--
		if li.aindex then
			LS:LinkAttachment(link, alist[li.aindex])
		elseif link then
			IntegrateLink(link, object, li.sub, li.is_source)
		end

		--
		box_layout.AddLine(cur, lo, ro, 5, link)
	end

	--
	local w, h = box_layout.GetSize()
	local ntext = AddNameText(bgroup, object)
	local box = AddBox(bgroup, max(w, ntext.width) + 35, h + 30)

	LS:AddKnotList(KnotListIndex)

	box.m_attachments = alist

	--
	KnotListIndex = KnotListIndex + 1

	ntext.y = box_layout.GetY1(box) + 10

	AssignPositions(box, alist, common.GetPositions(object))

	return box, ntext
end

local function RemoveBox (box)
	cells.RemoveFromCell(ItemGroup, box)

	box.parent:removeSelf()
end

--
local function RemoveAttachment (tag_db, sbox, tag)
	local links = sbox:GetLinksGroup()

	for k = 1, links.numChildren do
		tag = tag or tag_db:GetTag(links[k].m_obj)

		local instance = links[k].m_sub

		common.SetLabel(instance, nil)

		tag_db:Release(tag, instance)
	end

	RemoveBox(sbox)

	return tag
end

local function RemoveDeadObjects (LS)
--	local tag_db = common.GetLinks():GetTagDatabase()

	for _, state in objects.IterateRemovedObjects() do -- TODO: ??
		local box, tag = state.m_box

		LS:RemoveKnotList(box.m_knot_list_index)

		for j = 1, #(box.m_attachments or "") do
			tag = RemoveAttachment(tag_db, box.m_attachments[j], tag) -- TODO
		end

		RemoveBox(box)
	end	
end

local function AddNewObjects (LS)
	local links = common.GetLinks()
	local tag_db = links:GetTagDatabase()

	LastSpot = -1

	for _, object in objects.IterateNewObjects() do -- TODO: ids
		local box, name = AddPrimaryBox(ItemGroup, tag_db, links:GetTag(object), object)

		objects.AssociateBoxAndObject(object, box, name)
	end
end

local function MakeConnections (LS)
	for _, object in objects.IterateNewObjects("remove") do -- TODO: ids
		LS:ConnectObject(object)
	end

	LS:FinishConnecting()
end

local Event = {}

local function Dispatch (LS, name)
	Event.name = name

	LS.m_events:dispatchEvent(Event)
end

---
-- @pgroup view X
function M.Enter (_)
	--[[
	objects.Refresh()

	RemoveDeadObjects()
	AddNewObjects()
	MakeConnections()]]

	--
	Group.isVisible = true

	HelpContext:Show(true)
end

--- DOCME
function LinkScene:Enter ()
	self:Refresh()

	RemoveDeadObjects(self)
	AddNewObjects(self)
	MakeConnections(self)

	-- TODO: ^^^ stuff in sub-modules
	Dispatch(self, "enter")
end

--- DOCMAYBE
function M.Exit ()
	-- Tear down link groups

	Group.isVisible = false

	HelpContext:Show(false)
end

--- DOCME
function LinkScene:Exit ()
	self.m_group.isVisible = false

	self.m_help:Show(false)
-- ^^ TODO: move into dedicated stuff
	Dispatch(self, "exit")
end

--- DOCMAYBE
function M.Unload ()
	Group, Indices, ItemGroup, LinkInfoEx, Offset, Order = nil
--[[
	attachments.Unload()
	box_layout.Unload()
	cells.Unload()
	connections.Unload()
	globals.Unload()
	objects.Unload()
]]
	-- TODO: event listener?
end

--- DOCME
function LinkScene:GetEventDispatcher ()
	return self.m_events
end

--- DOCME
function LinkScene:Unload ()
	self.m_group, self.m_indices, self.m_item_group, self.m_link_info_ex, self.m_offset, self.m_order = nil
-- ^^ TODO: move more into dedicated sub-modules
	Dispatch(self, "unload")
end

-- This seems the most straightforward way to get these to the attachments module.
--attachments.AddUtils{ add_box = AddBox, integrate_link = IntegrateLink, link = Link }

--- DOCME
function M.New (linker)
	local ls = { m_linker = linker }

	ls.m_events = system.newEventDispatcher()

	return setmetatable(ls, LinkScene)
end

-- Export the module.
return M