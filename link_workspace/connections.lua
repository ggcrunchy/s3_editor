--- Management of link view connections.

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

-- Modules --
local box_layout = require("s3_editor_views.link_imp.box_layout")
local common = require("s3_editor.Common")
local link_group = require("corona_ui.widgets.link_group")
local objects = require("s3_editor_views.link_imp.objects")
local utils = require("s3_editor_views.link_imp.utils")

-- Unique member keys --
local _knot_lists = {}
local _link_group = {}

--
--
--

--- DOCME
function M:AddKnotList (id)
	self[_knot_lists][id] = {}
end

--- DOCME
function M:AddNode (id, is_export, node)
	self[_link_group]:AddLink(id, not is_export, node)
end

local function Connect (LG, node1, node2, knot)
	local link_scene = utils.FindLinkScene(LG)
	local linker = link_scene:GetLinker()
	local links = linker:GetLinkCollection()
--[[
	local id1, id2 = node1.m_id, node2.m_id

	for link in links:Links(id1, node1.m_name) do
		local id, name = link:GetOtherItem(id1)

		if  == obj2 then
			klink = link
		end
	end
]]
-- TODO: ^^^^ this might not be flexible enough, actually
-- actually actually, this should probably be filtered out by a CanLink() earlier?
	knot.m_link = links:LinkItems(node1.m_id, node2.m_id, node1.m_name, node2.m_name)
-- TODO: ^^^ sort of precarious, since as seen below we obviously already have ids in the nodes...
	local id1, id2 = link_group.GetLinkInfo(node1), link_group.GetLinkInfo(node2)
	local knot_lists = link_scene[_knot_lists]

	knot.m_id1, knot_lists[id1][id2] = id1, true
	knot.m_id2, knot_lists[id2][id1] = id2, true
-- ^^^ ARGH, this of course is broken for same ids but different names
-- need to review what's using it, but if nothing stands in the way,
-- something like ("%i:%s:%i:%s", id1, name1, id2, name2) ??
-- basically this is just to be reproducible in light of undo / redo
	common.Dirty()--[[
	linker:GetUndoRedoStack():Push(function(how)
		if how == "undo" then
			-- just remove it... (Break logic below)
		else
			-- find nodes
			-- relink
		end
	end)]]
end

local function GetList (LS, id)
	local knot_lists = LS[_knot_lists]

	return knot_lists[id] or _knot_lists	-- use key to avoid special-casing failure case
											-- being empty, nil'ing its members is a no-op
end

local KnotTouch = link_group.BreakTouchFunc(function(knot)
	knot.m_link:Break()

	local link_scene = utils.FindLinkScene(knot)
	local id1, id2 = knot.m_id1, knot.m_id2

	GetList(link_scene, id1)[id2], GetList(link_scene, id2)[id1] = nil

	common.Dirty()--[[
	linker:GetUndoRedoStack():Push(function(how)
		if how == "undo" then
			-- need to rebuild the above link
			-- logic from Connect, but might need to make sure that's okay sans GUI
		else
			-- find knot using ID and re-break it
		end
	end)]]
end)

--
local function FindLink (box, name)
	for _, group in box_layout.IterateGroupsOfNodes(box) do
		for i = 1, group.numChildren do
			local item = group[i]

			if item.m_name == name then
				return item
			end
		end
	end
end

local Knitting

local function AuxKnit (link, id, node1)
	if not (Knitting and Knitting[link]) then
		Knitting = Knitting or {}

		local link_scene, oid, oname = utils.FindLinkScene(node1), link:GetOtherItem(id)
		local knot = link_scene[_link_group]:ConnectObjects(node1, FindLink(objects.GetBox(other), oname))
-- ^^ TODO: id (could do now but reminds about objects.*)
		knot.m_link, Knitting[link] = link, true
	end
end

--
local function KnitNodes (links, group, id)
	for i = 1, group.numChildren do
		local node1 = group[i]
		local nname = node1.m_name

		if nname then -- TODO: is this to ignore templates, or what?
			links:ForEachItemLink(id, nname, AuxKnit, node1)
		end
	end
end

--- DOCME
function M:ConnectObject (object)
	local links = self:GetLinker():GetLinkCollection()

	for _, group in box_layout.IterateGroupsOfNodes(objects.GetBox(object)) do
		-- ^^ TODO: id
		KnitNodes(links, group, object)
	end
end

--- DOCME
function M:FinishConnecting ()
	Knitting = false
end

--- DOCME
function M:LinkAttachment (link, attachment)
	link_group.Connect(link, attachment.primary, false, self[_link_group]:GetGroups())

	link.alpha, attachment.primary.alpha = .025, .025 -- TODO: theme
end

local function CanLink (node1, node2)
	if Knitting then -- linking programmatically, e.g. loading from a save or during a redo
		return true
	else
		local link_scene = utils.FindLinkScene(node1)
		local links = link_scene:GetLinker():GetLinkCollection()

		-- TODO: this is one of two places that uses this, so
		-- decide how to play to that
		return common.GetLinks():CanLink(node1.m_id, node2.m_id, node1.m_name, node2.m_name)
	end
end

--- DOCME
function M:LoadConnections (group, emphasize, gather)
	self[_link_group] = link_group.LinkGroup(group, Connect, KnotTouch, {
		can_link = CanLink, emphasize = emphasize, gather = gather
	})
	self[_knot_lists] = {}
end

--- DOCME
function M:RemoveKnotList (id)
	local knot_lists = self[_knot_lists]
	local list = knot_lists[id]

	if list then -- attachments will share primary's list
		for knot in pairs(list) do
			link_group.Break(knot)
		end
	end

	knot_lists[id] = nil
end

--- DOCME
function M.Unload ()
--	LinkGroup, KnotLists = nil
end
-- TODO: the link group would be in the hierarchy, but if we remove the topmost object,
-- no need for this, just GC

return M