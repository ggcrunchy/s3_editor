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

-- Modules --
local common = require("s3_editor.Common")
local editor_strings = require("config.EditorStrings")
local help = require("s3_editor.Help")

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
local system = system

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

--

-- --
--cells.SetCellFraction(.35)

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
	connections.Load(link_layer)
	globals.Load(view)

	Group.isVisible = false
end

--
local function RemoveAttachment (LS, tag_db, sbox, tag)
	local nodes = sbox:GetLinksGroup()

	for i = 1, nodes.numChildren do
		tag = tag or tag_db:GetTag(nodes[i]:GetID()) -- TODO!

		local instance = nodes[i]:GetName() -- TODO!

		common.SetLabel(instance, nil) -- TODO!

		tag_db:Release(tag, instance)
		-- ^^ TODO: just a lookup by ID and then expunging it?
	end

	LS:RemoveBox(sbox)

	return tag
end

local function RemoveDeadObjects (LS)
--	local tag_db = common.GetLinks():GetTagDatabase()

	for _, state in objects.IterateRemovedObjects() do -- TODO: ??
		local box, tag = state.m_box

		LS:RemoveKnotList(box.m_knot_list_index)

		for _, abox in box:Attachments() do
			tag = RemoveAttachment(LS, tag_db, abox, tag) -- TODO
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
	Group, ItemGroup, LinkInfoEx, Offset = nil
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
function LinkScene:GetLinker ()
	return self.m_linker
end

--- DOCME
function LinkScene:Unload ()
	self.m_group, self.m_item_group, self.m_link_info_ex, self.m_offset = nil
-- ^^ TODO: move more into dedicated sub-modules
	Dispatch(self, "unload")
end

--- DOCME
function M.New (linker)
	local ls = { m_linker = linker }

	ls.m_events = system.newEventDispatcher()

	return setmetatable(ls, LinkScene)
end

return M