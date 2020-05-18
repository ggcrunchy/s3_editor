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
local sort = table.sort

-- Modules --
local box_layout = require("s3_editor.link_workspace.box_layout")
local function_set = require("s3_editor.FunctionSet")
local node_group = require("solar2d_ui.widgets.node_group")
local theme = require("s3_editor.link_workspace.theme")
local utils = require("s3_editor_views.link_imp.utils")

-- Corona globals --
local transition = transition

-- Unique member keys --
local _knot_lists = {}
local _node_group = {}
local _prev_id = {}
local _prev_name = {}
local _prev_pattern = {}
local _prev_side = {}

--
--
--

--- DOCME
function M:AddKnotList (id)
	self[_knot_lists][id] = {}
end

--- DOCME
function M:AddNode (id, node)
	local node_pattern = self:GetNodePattern(id)

	self[_node_group]:AddNode(id, self:GetNodeSide(node_pattern, node:GetName()), node)
end

local function AuxAreAlreadyLinked (link, id, other)
	local oid, oname = link:GetOtherItem(id)

	if oid == other:GetID() and oname == other:GetName() then
		other.m_already_linked = true
	end
end

local function AreAlreadyLinked (links, node1, node2)
	node2.m_already_linked = nil

	links:ForEachItemLink(node1:GetID(), node1:GetName(), AuxAreAlreadyLinked, node2)

	return node2.m_already_linked
end

--- DOCME
local function CanLink (node1, node2)
--		p1, p2, sub1, sub2, object1, object2 = SortProxies(p1, p2, sub1, sub2, object1, object2)

	if node1 == node2 then
		return false, "Same object"
	end

	local link_scene = utils.FindLinkScene(node1)
	local linker = link_scene:GetLinker()
	local links = linker:GetLinkCollection()

	if AreAlreadyLinked(links, node1, node2) then
		return false, "Already linked"
	else
		--[[
		local tag_db = self[_tag_db]

		-- ...pass all object1-object2 predicates?
		local passed, why, is_cont = tag_db:CanLink(p1.name, p2.name, object1, object2, sub1, sub2, self)

		if passed then
			-- ...and object2-object1 ones too?
			passed, why, is_cont = tag_db:CanLink(p2.name, p1.name, object2, object1, sub2, sub1, self)

			if passed then
				return true
			end
		end

		return false, why, is_cont]]
		-- TODO: get node patterns of each and then can_link() them?
			-- from Linkable:
				-- can_link (node, other, name, oname[, linker]) also ids
	end
end

local function UndoRedoConnect (how)
	if how == "undo" then
		-- just remove it... (Break logic below)
	else
		-- find nodes
		-- relink
	end
end

local function Connect (NG, node1, node2, knot)
	local link_scene = utils.FindLinkScene(NG)
	local linker = link_scene:GetLinker()
	local links = linker:GetLinkCollection()

	knot.m_link = links:LinkItems(node1:GetID(), node2:GetID(), node1:GetName(), node2:GetName())

	local id1, id2 = node_group.GetLinkInfo(node1), node_group.GetLinkInfo(node2)
	local knot_lists = link_scene[_knot_lists]

	knot.m_id1, knot_lists[id1][id2] = id1, true
	knot.m_id2, knot_lists[id2][id1] = id2, true
-- ^^^ TODO: ARGH, this of course is broken for same ids but different names
-- need to review what's using it, but if nothing stands in the way,
-- something like ("%i:%s:%i:%s", id1, name1, id2, name2) ??
-- basically this is just to be reproducible in light of undo / redo
	linker:GetUndoRedoStack():Push(UndoRedoConnect)
end

local function GetList (LS, id)
	local knot_lists = LS[_knot_lists]

	return knot_lists[id] or _knot_lists	-- use key to avoid special-casing failure case
											-- being empty, nil'ing its members is a no-op
end

local function UndoRedoBreakKnot (how)
	if how == "undo" then
		-- need to rebuild the above link
		-- logic from Connect, but might need to make sure that's okay sans GUI
	else
		-- find knot using ID and re-break it
	end
end

local KnotTouch = node_group.BreakTouchFunc(function(knot)
	knot.m_link:Break()

	local link_scene = utils.FindLinkScene(knot)
	local id1, id2 = knot.m_id1, knot.m_id2

	GetList(link_scene, id1)[id2], GetList(link_scene, id2)[id1] = nil

	link_scene:GetLinker():GetUndoRedoStack():Push(UndoRedoBreakKnot)
end)

--
local function FindNode (box, name) -- TODO: want box id?
	for _, group in box_layout.IterateGroupsOfNodes(box) do -- TODO
		for i = 1, group.numChildren do
			local item = group[i]

			if item:GetName() == name then
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
		local obox = link_scene:GetAssociatedBox(oid)
		local knot = link_scene[_node_group]:ConnectObjects(node1, FindNode(obox, oname))

		knot.m_link, Knitting[link] = link, true
	end
end

--
local function KnitNodes (links, group, id)
	for i = 1, group.numChildren do
		local node1 = group[i]
		local nname = node1:GetName()

		if nname then -- TODO: is this to ignore templates, or what?
			links:ForEachItemLink(id, nname, AuxKnit, node1)
		end
	end
end

--- DOCME
function M:ConnectObject (id)
	local links = self:GetLinker():GetLinkCollection()

	for _, group in box_layout.IterateGroupsOfNodes(self:GetAssociatedBox(id)) do -- TODO
		KnitNodes(links, group, id)
	end
end

--- DOCME
function M:FinishConnecting ()
	Knitting = false
end

--- DOCME
function M:GetNodePattern (id)
	if self[_prev_id] == id then -- avoid some redundancy
		return self[_prev_pattern]
	else
		local linker = self:GetLinker()
		local values = linker:GetValuesFromIdentifier(id)
		local node_pattern = function_set.GetStateFromInstance(values).nodes

		self[_prev_id], self[_prev_pattern] = id, node_pattern	-- see also GetNodeSide(), but this should
																-- be compatible with its access pattern

		return node_pattern
	end
end

local function AuxGetNodeSide (node_pattern, name)
	if node_pattern:HasNode(name, "exports") then
		return "rhs"
	elseif node_pattern:HasNode(name, "imports") then
		return "lhs"
	else
		return "none"
	end
end

--- DOCME
function M:GetNodeSide (node_pattern, name)
	if self[_prev_pattern] == node_pattern and self[_prev_name] == name then	-- avoid some redundancy
		return self[_prev_side]
	else
		name = node_pattern:GetTemplate(name) or name

		local side = AuxGetNodeSide(node_pattern, name)

		self[_prev_name], self[_prev_pattern], self[_prev_side] = name, node_pattern, side

		return side
	end
end

--- DOCME
function M:GetSideOppositeNode (node_pattern, name)
	local side = self:GetNodeSide(node_pattern, name)

	if side == "lhs" or side == "rhs" then
		side = side == "lhs" and "rhs" or "lhs"
	end

	return side
end

--- DOCME
function M:LinkAttachment (node, attachment)
	node_group.Connect(node, attachment.primary, false, self[_node_group]:GetGroups())

	local alpha = theme.AttachmentNodeAlpha()

	node.alpha, attachment.primary.alpha = alpha, alpha
end

local NodeGroupOpts = {}

function NodeGroupOpts.can_link (node1, node2)
	if Knitting then -- linking programmatically, e.g. loading from a save or during a redo
		return true
	else
		return CanLink(node1, node2)
	end
end


local FadeParams = {}

function NodeGroupOpts.emphasize (item, how, node, export_to_import, not_owner)
	local r, g, b = 1

	if item.m_glowing then
		transition.cancel(item.m_glowing)

		item.m_glowing = nil
	end

	if how == "began" then
		if not not_owner then
			r, g, b = theme.EmphasizeOwner(FadeParams)
		elseif not export_to_import then
			r, g, b = theme.EmphasizeNotExportToImport(FadeParams)
		elseif CanLink(node, item) then
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
	return box1:GetID() > box2:GetID()
end

function NodeGroupOpts.gather (items)
	local boxes_seen = items.m_boxes_seen or {}

--	cells.GatherVisibleBoxes(Offset.x, Offset.y, boxes_seen)
	-- ^^^ TODO: almost certainly going to drop the cells as they currently are,
	-- but might still be useful for these sorts of visibility queries, in which
	-- case offset should stick around

	sort(boxes_seen, SortByID) -- make links agree with render order

	for i = 1, #boxes_seen do
		for _, group in box_layout.IterateGroupsOfNodes(boxes_seen[i]) do -- TODO?
			for j = 1, group.numChildren do
				items[#items + 1] = group[j]
			end
		end
	end

	items.m_boxes_seen = boxes_seen
end

--- DOCME
function M:LoadConnections (group)
	self[_node_group] = node_group.NodeGroup(group, Connect, KnotTouch, NodeGroupOpts)
	self[_knot_lists] = {}
end

--- DOCME
function M:RemoveKnotList (id)
	local knot_lists = self[_knot_lists]
	local list = knot_lists[id]

	if list then -- attachments will share primary's list
		for knot in pairs(list) do -- TODO: broken...
			node_group.Break(knot)
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