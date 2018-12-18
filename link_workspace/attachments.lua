--- Management of link view attachments.

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
local tonumber = tonumber

-- Modules --
local array_index = require("tektite_core.array.index")
local box_layout = require("s3_editor_views.link_imp.box_layout")
local button = require("corona_ui.widgets.button")
local editable = require("corona_ui.patterns.editable")
local common = require("s3_editor.Common")
local layout = require("corona_ui.utils.layout")
local table_view_patterns = require("corona_ui.patterns.table_view")
local theme = require("s3_editor.link_workspace.theme")
local touch = require("corona_ui.utils.touch")
local utils = require("s3_editor.link_workspace.utils")

-- Corona globals --
local display = display
local native = native

-- Unique member keys --

-- Exports --
local M = {}

--
--
--

local function RemoveRange (list, last, n)
	for _ = 1, n do
		list:remove(last)

		last = last - 1
	end
end

local function Shift (linker, items, shift, a, b, is_array)
	local delta = shift > 0 and 1 or -1

	for i = a, b, delta do
		local gend = is_array and items[i].m_generated_name

		if gend then
			linker:SetLabel(gend, linker:GetLabel(gend) + delta)
		end

		items[i].y = items[i + shift].y
	end
end

local function RemoveRow (linker, list, row, n, is_array)
	local last = row * n

	Shift(linker, list, -n, list.numChildren, last + 1, is_array)
	RemoveRange(list, last, n)
end

local function ObjectToAttachmentGroup (object)
	local group = object.parent

	return group.parent, group
end

local Delete = touch.TouchHelperFunc(function(_, button)
	local linker = utils.FindLinkScene(button):GetLinker()
	local agroup, fixed = ObjectToAttachmentGroup(button)
	local row, items, nodes = button.m_row, agroup.items, agroup.nodes
	local nfixed, nnodes = fixed.numChildren, nodes.numChildren
	local neach = items.numChildren / nnodes -- only one node per row, but maybe multiple items
	local base = (row - 1) * neach

	for i = 1, neach do
		local gend = items[base + i].m_generated_name

		if gend then
			linker:RemoveGeneratedName(button.m_id, gend)
		end
	end

	local box = agroup:FindBox()

	RemoveRow(linker, items, row, neach, box.m_style == "array")--items.m_is_array)
	RemoveRow(linker, nodes, row, 1)
	RemoveRange(fixed, nfixed, nfixed / nnodes) -- as above, in case multiple fixed objects per row

	common.Dirty()--[[
	linker:GetUndoRedoStack():Push(...)
		TODO!
	]]
end)

local function GetFromItemInfo (linker, items, fi, ti, n, is_array)
	for i = 0, n - 1 do
		local from_gend = is_array and items[ti - i].m_generated_name

		if from_gend then
			items[fi - i].m_old_index = linker:GetLabel(from_gend)
		end

		items[fi - i].m_y = items[ti - i].y
	end
end

local function SetToItemInfo (linker, items, _, ti, n)
	for i = 0, n - 1 do
		local item = items[ti - i]

		if item.m_old_index then
			linker:SetLabel(item.m_generated_name, item.m_old_index)
		end

		item.y, item.m_old_index, item.m_y = item.m_y
	end
end

local function AuxMoveRow (linker, items, stash, fi, ti, n, is_array)
	GetFromItemInfo(linker, items, fi, ti, n, is_array)

	local tpos = ti - n + 1

	if fi < ti then
		Shift(linker, items, -n, ti, fi + 1, is_array)
	else
		Shift(linker, items, n, tpos, fi - n, is_array)
	end

	for i = 0, n - 1 do -- to avoid having to reason about how insert() works with elements already in the group,
						-- temporarily put them somewhere else, in reverse order...
		stash:insert(items[fi - i])
	end

	for i = 1, n do -- ...then stitch them back in where they belong
		items:insert(tpos, stash[stash.numChildren - n + i])
	end

	SetToItemInfo(linker, items, fi, ti, n)
end

local function MoveRow (items, nodes, from, to)
	if from ~= to then
		local box = items.parent:FindBox()
		local n = items.numChildren / nodes.numChildren -- only one node per row, but maybe multiple items
		local fi, ti = from * n, to * n
		local linker = utils.FindLinkScene(items):GetLinker()

		AuxMoveRow(linker, items, nodes, fi, ti, n, box.m_style == "array")--items.m_is_array)
		AuxMoveRow(linker, nodes, items, from, to, 1)
	end
end

local function FindRow (drag_box, box, nodes)
	local row = array_index.FitToSlot(drag_box.y, box.y + box.height / 2, drag_box.height)

	return (row >= 1 and row <= nodes.numChildren) and row
end

local Move = touch.TouchHelperFunc(function(event, ibox)
	local agroup = ObjectToAttachmentGroup(ibox)
	local box = agroup:FindBox()
	local drag_box = box.m_drag

	drag_box.x, drag_box.y = ibox.x, ibox.y
	drag_box.isVisible = true

	ibox.m_dragy, ibox.m_from = ibox.y - event.y, FindRow(drag_box, box, agroup.nodes)
end, function(event, ibox)
	local agroup = ObjectToAttachmentGroup(ibox)

	agroup:GetBox().m_drag.y = ibox.m_dragy + event.y
end, function(_, ibox)
	local agroup, items = ObjectToAttachmentGroup(ibox)
	local box = agroup:GetBox()
	local drag_box, nodes = box.m_drag, agroup.nodes
	local row = FindRow(drag_box, box, items, nodes)

	if row then
		MoveRow(items, nodes, ibox.m_from, row)
	end

	drag_box.isVisible = false
end)

local function IndexFromGeneratedName (linker, gend)
	return tonumber(linker:GetLabel(gend))
end

local function AssembleArray (linker, node_pattern, template, generated_names)
	local arr

	for i = 1, #(generated_names or "") do
		local gend = generated_names[i]

		if node_pattern:GetTemplate(gend) == template then
			arr = arr or {}
			arr[IndexFromGeneratedName(linker, gend)] = gend
		end
	end

	return arr
end

local EditOpts = {
	font = theme.AttachmentTextEditFont(), size = theme.AttachmentTextEditSize(),

	get_editable_text = function(editable)
		return common.GetLabel(editable.m_generated_name)
	end,

	set_editable_text = function(editable, text)
		common.SetLabel(editable.m_generated_name, text)

		editable:SetStringText(text)
	end
}

-- --
local ListboxOpts

--
local function DefGetText (text)
	return text
end

local function GetListboxOpts (get_text)
	ListboxOpts = ListboxOpts or {}

	for i = 1, #ListboxOpts do
		if ListboxOpts[i].get_text == get_text then
			return ListboxOpts[i]
		end
	end

	local opts = theme.ListboxOpts()

	ListboxOpts[#ListboxOpts + 1], opts.get_text = opts, get_text

	return opts
end

local function Mixed (agroup, info, primary_node, add, is_export)
	local get_text, choice = info.get_text or DefGetText
	local opts, ctext = GetListboxOpts(get_text), info.choice_text or "Choice:" -- TODO: theme

	choice = table_view_patterns.Listbox(agroup, opts)
	ctext = display.newText(agroup, ctext, 0, 0, native.systemFont, 15) -- TODO: theme
	choice.y = ctext.y -- Hmm, was this significant? :P

	info.add_choices(choice)

	if not choice:GetSelection() then
		choice:Select(1)
	end

	if is_export then
		return choice, box_layout.Arrange(false, 7, primary_node, ctext, choice, add) -- TODO: theme
	else
		return choice, box_layout.Arrange(false, 7, ctext, choice, add, primary_node)
	end
end

local function GetNodesGroup (box)
	return box.parent.nodes
end

local function ItemBox (box, agroup, n, w, set_style)
	local ibox = theme.ItemBox(agroup.items, box.x, w, set_style)

	ibox:addEventListener("touch", Move)

	local below = box.y + box.height / 2

	ibox.y = below + (n - .5) * ibox.height

	if not box.m_drag then
		box.m_drag = theme.ItemBoxDragger(agroup, ibox)

		box.m_drag:toFront()
	end

	return ibox
end

local function Set (LS, agroup, ibox, gend)
	local linker, text = LS:GetLinker(), editable.Editable_XY(agroup.items, ibox.x, ibox.y, EditOpts)

	text.m_generated_name = gend

	text:SetText(linker:GetLabel(gend) or "default")

	return text
end

local function RowCount (agroup)
	return agroup.nodes.numChildren
end

local MURG = {
	array = function(_, agroup, ibox, gend)
		ibox.m_generated_name = gend

		local n = RowCount(agroup)

		display.newText(agroup.fixed, ("#%i"):format(n), ibox.x, ibox.y, native.systemFontBold, 10) -- TODO: theme
	end,

	mixed = function(LS, agroup, ibox, gend, id)
		local text = Set(LS, agroup, ibox, gend)
		local node_pattern = LS:GetNodePattern(id)
		local atext = sub[node_pattern:GetTemplate(gend)] -- TODO! sub -> info
		local about = display.newText(agroup.items, atext, 0, ibox.y, native.systemFont, 15) -- TODO: theme

		layout.PutLeftOf(about, text, -10) -- TODO: theme
	end,

	set = Set
}

local function AddRow (LS, box, id, gend)
	local agroup, is_export--[[, set_style]] = box.parent, box.m_is_export--, box.m_set_style
	local n, w = RowCount(agroup), theme.AttachmentRowWidth(box.width, box.m_style)
	local ibox = ItemBox(box, agroup, n, w, box.m_style)--set_style)
	local node, hw = theme.Node(agroup.nodes), w / 2

	node.x = box.x + (is_export and hw or -hw)
	node.y = ibox.y

	local delete = theme.DeleteButton(agroup.fixed, ibox)

	delete:addEventListener("touch", Delete)

	delete.x = box.x + (is_export and -hw or hw)

	delete.m_id, delete.m_row = id, n
--[[
	if set_style then
		local linker, text = LS:GetLinker(), editable.Editable_XY(agroup.items, ibox.x, ibox.y, EditOpts)

		text.m_generated_name = gend

		text:SetText(linker:GetLabel(gend) or "default")

		if set_style == "mixed" then
			local node_pattern = LS:GetNodePattern(id)
			local atext = sub[node_pattern:GetTemplate(gend)] -- TODO! sub -> info
			local about = display.newText(agroup.items, atext, 0, ibox.y, native.systemFont, 15) -- TODO: theme

			layout.PutLeftOf(about, text, -10) -- TODO: theme
		end
	else
		ibox.m_generated_name = gend

		display.newText(agroup.fixed, ("#%i"):format(n), ibox.x, ibox.y, native.systemFontBold, 10) -- TODO: theme
	end
]]
	MURG[box.m_style](LS, agroup, ibox, gend, id)
	-- ^^ TODO: good place to divvy this up

	LS:IntegrateNode(node, id, gend, is_export, box.m_knot_list_index)
end

local function GenerateName (LS, id, template, n)
	local linker, node_pattern = LS:GetLinker(), LS:GetNodePattern(id)
	local gend = node_pattern:Generate(template)

	linker:AddGeneratedName(id, gend)
	linker:SetLabel(gend, n) -- n.b. no-op if false

	common.Dirty()--[[
		linker:GetUndoRedoStack():Push(...)
		TODO!
	]]

	return gend
end

local function MakeRow (button)
	local agroup, id, link_scene = button.parent, button.m_id, utils.FindLinkScene(button)
	local box = agroup:FindBox()--, agroup.nodes.numChildren
	-- ^^ TODO: object (id) associated with box...
	local template = button.m_template or box.m_choice:GetSelectionData()
	local gend = GenerateName(link_scene, id, template, box.m_style == "array" and RowCount(agroup))--not box.m_set_style)

	AddRow(link_scene, box, id, gend)
end

local function AddSubGroups (agroup)--, is_array)
	agroup.items, agroup.fixed, agroup.nodes = display.newGroup(), display.newGroup(), display.newGroup()

	agroup:insert(agroup.items)
	agroup:insert(agroup.fixed)
	agroup:insert(agroup.nodes)

--	agroup.items.m_is_array = is_array
end

local function SETUP (group, id)
	local agroup = display.newGroup()

	group:insert(agroup)

	local make, primary_node = button.Button(agroup, "4.25%", "4%", MakeRow, "+"), theme.Node(agroup) -- TODO: theme

	make.m_id = id -- TODO: see if able to find via box, cf. note in MakeRow()

	return agroup, make, primary_node
end

local ACC = {}

local function ACCUMULATE_AND_DO (LS, box, id, func, arg)
	local linker, node_pattern = LS:GetLinker(), LS:GetNodePattern(id)
	local generated_names, count = linker:GetGeneratedNames(id), 0

	for i = 1, #(generated_names or "") do
		local gend = generated_names[i]
		local ok, key = func(node_pattern, gend, arg, linker)

		if ok then
			ACC[key or (count + 1)], count = gend, count + 1
		end
	end

	for i = 1, count do
		AddRow(LS, box, id, ACC[i])
	end

	return box
end

local function SET (node_pattern, gend, template)
	return node_pattern:GetTemplate(gend) == template
end

local function MIXED (node_pattern, gend, info)
	return info[node_pattern:GetTemplate(gend)]
end

local function ARRAY (node_pattern, gend, name, linker)
	if SET(node_pattern, gend, name) then
		return true, tonumber(linker:GetLabel(gend))
	end
end

local function MIRBLE (LS, agroup, make, primary_node, lo, ro)
	local w, midx = box_layout.GetLineWidth(lo, ro, "want_middle")
	local box = LS:AddBox(agroup, w + 25, make.height + 15) -- TODO: theme

	box.primary, box.x = primary_node, agroup:contentToLocal(midx, 0)

	AddSubGroups(agroup)--, not set_style)

	box.GetNodesGroup = GetNodesGroup

	return box
end

local function NOT_MIXED (primary_node, make, is_export, template)
	make.m_template = template
 
	return box_layout.Arrange(not is_export, 10, primary_node, make) -- TODO: theme
end

--- DOCME
function M:ArrayAttachmentBox (group, id, template, is_export)
	local agroup, make, primary_node = SETUP(group, id)
	local lo, ro = NOT_MIXED(primary_node, make, is_export, template)
	local box = MIRBLE(self, agroup, make, primary_node, lo, ro)
	box.m_is_export, box.m_style = is_export, "array"
	ACCUMULATE_AND_DO(self, box, id, ARRAY, template)
end

--- DOCME
function M:MixedAttachmentBox (group, id, info, is_export)
	local agroup, make, primary_node = SETUP(group, id)
	local choice, lo, ro = Mixed(agroup, info, primary_node, make, is_export)
	local box = MIRBLE(self, agroup, make, primary_node, lo, ro)
	box.m_choice, box.m_is_export, box.m_style = choice, is_export, "mixed"
	ACCUMULATE_AND_DO(self, box, id, MIXED, info)
end

--- DOCME
function M:SetAttachmentBox (group, id, template, is_export)
	local agroup, make, primary_node = SETUP(group, id)
	local lo, ro = NOT_MIXED(primary_node, make, is_export, template)
	local box = MIRBLE(self, agroup, make, primary_node, lo, ro)
	box.m_is_export, box.m_style = is_export, "set"
	ACCUMULATE_AND_DO(self, box, id, SET, template)
end

--- DOCME
function M:AttachmentBox (group, id, info, is_export, set_style)
	-- sub (errr... info) will be "template", then... maybe export-ness can be discovered too?
	-- maybe could even just break up into two functions soon, one for "mixed" and another for rest
--[[
	local agroup = display.newGroup()

	group:insert(agroup)

	local make, primary_node = button.Button(agroup, "4.25%", "4%", MakeRow, "+"), theme.Node(agroup) -- TODO: theme]]
	local agroup, make, primary_node = SETUP(group, id)
	local choice, lo, ro

--	make.m_id = id -- TODO: see if able to find via box, cf. note in MakeRow()

	if set_style ~= "mixed" then
		lo, ro = box_layout.Arrange(not is_export, 10, primary_node, make) -- TODO: theme
		make.m_template = info
	else
		choice, lo, ro = Mixed(agroup, info, primary_node, make, is_export)
	end

	local w, midx = box_layout.GetLineWidth(lo, ro, "want_middle")
	local box = self:AddBox(agroup, w + 25, make.height + 15) -- TODO: theme

	box.primary, box.x = primary_node, agroup:contentToLocal(midx, 0)

	AddSubGroups(agroup)--, not set_style)

	box.m_choice = choice
	box.m_is_export = is_export
	box.m_set_style = set_style

	box.GetNodesGroup = GetNodesGroup

	local linker, node_pattern = self:GetLinker(), self:GetNodePattern(id)
	local generated_names = linker:GetGeneratedNames(id)

	if set_style then
		for i = 1, #(generated_names or "") do
			local gend = generated_names[i]
			local template = node_pattern:GetTemplate(gend)

			if set_style ~= "mixed" then
				if template == info then
					AddRow(self, box, id, gend)
				end
			elseif info[template] then
				AddRow(self, box, id, gend)
			end
		end
	else
		local arr = AssembleArray(linker, node_pattern, info, generated_names)

		for i = 1, #(arr or "") do
			AddRow(self, box, id, arr[i])
		end
	end

	return box
end

--- DOCME
function M.Unload ()
	ListboxOpts = nil
end

return M