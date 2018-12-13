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
local pairs = pairs
local setmetatable = setmetatable
local sort = table.sort

-- Modules --
local common = require("s3_editor.Common")
local editor_strings = require("config.EditorStrings")
local help = require("s3_editor.Help")
local theme = require("s3_editor.link_workspace.theme")
local touch = require("corona_ui.utils.touch")

local method_augments = {
	require("s3_editor.link_workspace.attachments"),
	require("s3_editor.link_workspace.box"),
	require("s3_editor.link_workspace.box_layout"),
	require("s3_editor.link_workspace.cells"), -- TODO: remove
	require("s3_editor.link_workspace.connections"),
	require("s3_editor.link_workspace.globals"), -- TODO: remove
	require("s3_editor.link_workspace.objects")
}

-- Corona globals --
local display = display
local easing = easing
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

local KnotListIndex = 0

function M:IntegrateLink (link, object, sub, is_export, index)
	self:AddLink(index or KnotListIndex, not is_export, link)

	link.m_obj, link.m_sub = object, sub
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
			r, g, b = theme.EmphasizeOwner(FadeParams)
		elseif not source_to_target then
			r, g, b = theme.EmphasizeNotSourceToTarget(FadeParams)
		elseif common.GetLinks():CanLink(link.m_obj, item.m_obj, link.m_sub, item.m_sub) then
			r, g, b = theme.EmphasizeCanLink(FadeParams)
		else
			r, g, b = theme.EmphasizeDefault(FadeParams)
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

--
local function RemoveAttachment (LS, tag_db, sbox, tag)
	local links = sbox:GetLinksGroup()

	for k = 1, links.numChildren do
		tag = tag or tag_db:GetTag(links[k].m_obj)

		local instance = links[k].m_sub

		common.SetLabel(instance, nil)

		tag_db:Release(tag, instance)
	end

	LS:RemoveBox(sbox)

	return tag
end

local function RemoveDeadObjects (LS)
--	local tag_db = common.GetLinks():GetTagDatabase()

	for _, state in objects.IterateRemovedObjects() do -- TODO: ??
		local box, tag = state.m_box

		LS:RemoveKnotList(box.m_knot_list_index)

		for j = 1, #(box.m_attachments or "") do
			tag = RemoveAttachment(LS, tag_db, box.m_attachments[j], tag) -- TODO
		end

		LS:RemoveBox(box)
	end	
end

local function AddNewObjects (LS)
	local links = common.GetLinks()
	local tag_db = links:GetTagDatabase()

--	LastSpot = -1

	for _, object in objects.IterateNewObjects() do -- TODO: ids
		local box, name = LS:AddPrimaryBox(ItemGroup, tag_db, links:GetTag(object), object)

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

return M