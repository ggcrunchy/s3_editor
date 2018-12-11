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

-- Unique member keys --
local _doing_links = {}
local _knot_lists = {}
local _link_group = {}

--
--
--

--- DOCME
function M:AddLink (id, is_export, link)
	self[_link_group]:AddLink(id, not is_export, link)
end

--local KnotLists

--- DOCME
function M.AddKnotList (id)
	KnotLists[id] = {}
end

--local function FindLink (

local function Connect (LG, node1, node2, knot)
	-- LG -> linker
	local links, klink = linker:GetLinkCollection()
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
	knot.m_link = klink or links:LinkItems(node1.m_id, node2.m_id, node1.m_name, node2.m_name)
-- TODO: ^^^ sort of precarious, since as seen below we obviously already have ids in the nodes...
	local id1, id2 = link_group.GetLinkInfo(node1), link_group.GetLinkInfo(node2)
	local kl1, kl2 = KnotLists[id1], KnotLists[id2]

	knot.m_id1, knot.m_id2 = id1, id2
	kl1[knot], kl2[knot] = true, true
-- TODO: rather than use knot here, use say strings.PairToKey(id1, id2) here, since
-- presumably it's more robust after Redo or Undo
-- TODO: actually, reciprocating ids might work, i.e. kl1[id2], kl2[id1]
	common.Dirty()
end

local function GetList (id)
	return KnotLists[id] or KnotLists	-- use KnotLists to avoid special-casing failure case
										-- KnotLists[knot] is already absent, so nil'ing it is a no-op
end

local KnotTouch = link_group.BreakTouchFunc(function(knot)
	knot.m_link:Break()

	GetList(knot.m_id1)[knot], GetList(knot.m_id2)[knot] = nil
-- TODO: see TODO in Connect
	common.Dirty()
end)

--local DoingLinks

--
local function FindLink (box, name)
	for _, group in box_layout.IterateGroupsOfLinks(box) do
		for i = 1, group.numChildren do
			local item = group[i]

			if item.m_name == name then
				return item
			end
		end
	end
end

local function AuxForEach (link, LS, link1)
	LS[_doing_links] = LS[_doing_links] or {}

	if not LS[_doing_links][link] then
		local oid, oname = link:GetOtherItem(object) -- TODO: id
		local knot = LS[_link_group]:ConnectObjects(link1, FindLink(objects.GetBox(other), oname))

		knot.m_link, LS[_doing_links][link] = link, true
	end
end

--
local function DoLinks (LS, links, group, object)
	for i = 1, group.numChildren do
		local link1 = group[i]
		local lname = link1.m_name

		if lname then
		--	for link in links:Links(object, lname) do
			links:ForEachItemLink(object, lname, AuxForEach, LS, link1) -- TODO: id
		--	end
		end
	end
end

--- DOCME
function M:ConnectObject (object)
	local links = self.m_links

	for _, group in box_layout.IterateGroupsOfLinks(objects.GetBox(object)) do
		DoLinks(self, links, group, object)
	end
end

--- DOCME
function M:FinishConnecting ()
	self[_doing_links] = false
end

--- DOCME
function M:LinkAttachment (link, attachment)
	link_group.Connect(link, attachment.primary, false, self[_link_group]:GetGroups())

	link.alpha, attachment.primary.alpha = .025, .025
end

--- DOCME
function M:LoadConnections (group, emphasize, gather)
	self[_link_group] = link_group.LinkGroup(group, Connect, KnotTouch, {
		can_link = function(node1, node2)
			return DoingLinks or common.GetLinks():CanLink(node1.m_id, node2.m_id, node1.m_name, node2.m_name)
		end, emphasize = emphasize, gather = gather
	})
	self[_knot_lists] = {}
	self[_doing_links] = false
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
	LinkGroup, KnotLists = nil
end

-- Export the module.
return M