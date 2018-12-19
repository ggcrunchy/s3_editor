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
local attachment_list = require("s3_editor.link_workspace.attachment_list")
local box_layout = require("s3_editor.link_workspace.box_layout")
local button = require("corona_ui.widgets.button")
local editable = require("corona_ui.patterns.editable")
local layout = require("corona_ui.utils.layout")
local table_view_patterns = require("corona_ui.patterns.table_view")
local theme = require("s3_editor.link_workspace.theme")
local touch = require("corona_ui.utils.touch")
local utils = require("s3_editor.link_workspace.utils")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

local function ObjectToAttachmentGroup (object)
	local group = object.parent

	return group.parent, group
end

local function UndoRedoDelete (how)
	if how == "undo" then
		-- TODO!
	else
		-- TODO!
	end
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

	attachment_list.RemoveRow(linker, items, row, neach, box.m_style == "array")
	attachment_list.RemoveRow(linker, nodes, row, 1)
	attachment_list.RemoveRange(fixed, nfixed, nfixed / nnodes) -- cf. note for neach, above

	linker:GetUndoRedoStack():Push(UndoRedoDelete)
end)

local Move = touch.TouchHelperFunc(function(event, ibox)
	local agroup = ObjectToAttachmentGroup(ibox)
	local box = agroup:FindBox()
	local drag_box = box.m_drag

	drag_box.x, drag_box.y = ibox.x, ibox.y
	drag_box.isVisible = true

	ibox.m_dragy, ibox.m_from = ibox.y - event.y, attachment_list.FindRow(drag_box, box, agroup.nodes)
end, function(event, ibox)
	local agroup = ObjectToAttachmentGroup(ibox)

	agroup:GetBox().m_drag.y = ibox.m_dragy + event.y
end, function(_, ibox)
	local agroup, items = ObjectToAttachmentGroup(ibox)
	local box = agroup:GetBox()
	local drag_box, nodes = box.m_drag, agroup.nodes
	local row = attachment_list.FindRow(drag_box, box, items, nodes)

	if row then
		attachment_list.MoveRow(items, nodes, ibox.m_from, row)
	end

	drag_box.isVisible = false
end)

local EditOpts = {
	font = theme.AttachmentTextEditFont(), size = theme.AttachmentTextEditSize(),

	get_editable_text = function(editable)
		local linker = utils.FindLinkScene(editable):GetLinker()

		return linker:GetLabel(editable.m_generated_name)
	end,

	set_editable_text = function(editable, text)
		local linker = utils.FindLinkScene(editable):GetLinker()

		linker:SetLabel(editable.m_generated_name, text)
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

local function AddNameToSet (LS, agroup, ibox, gend)
	local linker, text = LS:GetLinker(), editable.Editable_XY(agroup.items, ibox.x, ibox.y, EditOpts)

	text.m_generated_name = gend

	text:SetText(linker:GetLabel(gend) or "default")

	return text
end

local function RowCount (agroup)
	return agroup.nodes.numChildren
end

local AddName = {
	array = function(_, agroup, ibox, gend)
		ibox.m_generated_name = gend

		local str = theme.AttachmentArrayIndexString(RowCount(agroup))

		display.newText(agroup.fixed, str, ibox.x, ibox.y, theme.AttachmentArrayTextParams())
	end,

	block = function(LS, agroup, ibox, gend, id)
		local text = AddNameToSet(LS, agroup, ibox, gend)
		local node_pattern = LS:GetNodePattern(id)
		local atext = agroup:FindBox().m_group_info[node_pattern:GetTemplate(gend)]
		local about = display.newText(agroup.items, atext, 0, ibox.y, theme.AboutTextParams())

		layout.PutLeftOf(about, text, theme.AboutOffset())
	end,

	set = AddNameToSet
}

local function AddRowToBox (LS, box, id, gend)
	local agroup, is_export = box.parent, box.m_is_export
	local n, w = RowCount(agroup), theme.AttachmentRowWidth(box.width, box.m_style)
	local ibox = ItemBox(box, agroup, n, w, box.m_style)
	local node, hw = theme.Node(agroup.nodes), w / 2

	node.x = box.x + (is_export and hw or -hw)
	node.y = ibox.y

	local delete = theme.DeleteButton(agroup.fixed, ibox)

	delete:addEventListener("touch", Delete)

	delete.x = box.x + (is_export and -hw or hw)

	delete.m_id, delete.m_row = id, n

	AddName[box.m_style](LS, agroup, ibox, gend, id)

	LS:IntegrateNode(node, id, gend, is_export, box.m_knot_list_index)
end

local function AddSubGroups (agroup)
	agroup.items, agroup.fixed, agroup.nodes = display.newGroup(), display.newGroup(), display.newGroup()

	agroup:insert(agroup.items)
	agroup:insert(agroup.fixed)
	agroup:insert(agroup.nodes)
end

local function MatchesTemplate (node_pattern, gend, template)
	return node_pattern:GetTemplate(gend) == template
end

local Accumulator = {}

local GatherFilters = {
	array = function(node_pattern, gend, name, linker)
		if MatchesTemplate(node_pattern, gend, name) then
			return true, tonumber(linker:GetLabel(gend))
		end
	end, set = MatchesTemplate
}

local function GatherAndAddRows (LS, box, id, arg)
	local linker, node_pattern = LS:GetLinker(), LS:GetNodePattern(id)
	local generated_names, count = linker:GetGeneratedNames(id), 0
	local filter = GatherFilters[box.m_style]

	for i = 1, #(generated_names or "") do
		local gend = generated_names[i]
		local ok, key = filter(node_pattern, gend, arg, linker)

		if ok then
			Accumulator[key or (count + 1)], count = gend, count + 1
		end
	end

	for i = 1, count do
		AddRowToBox(LS, box, id, Accumulator[i])
	end

	return box
end

local function GetNodesGroup (box)
	return box.parent.nodes
end

local function MakeBox (LS, agroup, make, primary_node, lo, ro)
	local w, midx = box_layout.GetLineWidth(lo, ro, "want_middle")
	local box = LS:AddBox(agroup, theme.AttachmentBoxSize(w, make.height))

	box.primary, box.x = primary_node, agroup:contentToLocal(midx, 0)

	AddSubGroups(agroup)

	box.GetNodesGroup = GetNodesGroup

	return box
end

local function UndoRedoGenerateName (how)
	if how == "undo" then
		-- TODO!
	else
		-- TODO!
	end
end

local function GenerateName (LS, id, template, n)
	local linker, node_pattern = LS:GetLinker(), LS:GetNodePattern(id)
	local gend = node_pattern:Generate(template)

	linker:AddGeneratedName(id, gend)
	linker:SetLabel(gend, n) -- n.b. no-op if false
	linker:GetUndoRedoStack():Push(UndoRedoGenerateName)

	return gend
end

local function MakeRow (button)
	local agroup, id, link_scene = button.parent, button.m_id, utils.FindLinkScene(button)
	local box = agroup:FindBox()
	-- ^^ TODO: object (id) associated with box...
	local template = button.m_template or box.m_choice:GetSelectionData()
	local gend = GenerateName(link_scene, id, template, box.m_style == "array" and RowCount(agroup))

	AddRowToBox(link_scene, box, id, gend)
end

local function MakeBoxObjects (group, id)
	local agroup = display.newGroup()

	group:insert(agroup)

	local primary_node, mw, mh = theme.Node(agroup), theme.MakeRowSize()
	local make = button.Button(agroup, mw, mh, MakeRow, theme.MakeRowText())

	make.m_id = id -- TODO: see if able to find via box, cf. note in MakeRow()

	return agroup, make, primary_node
end

--- DOCME
function M:AttachmentBox (group, id, template, is_export, style)
	local agroup, make, primary_node = MakeBoxObjects(group, id)
	local sep = theme.AttachmentBoxSeparationOffset()
	local lo, ro = box_layout.Arrange(not is_export, sep, primary_node, make)
	local box = MakeBox(self, agroup, make, primary_node, lo, ro)

	make.m_template, box.m_is_export, box.m_style = template, is_export, style

	return GatherAndAddRows(self, box, id, template)
end

function GatherFilters.block (node_pattern, gend, list)
	return list[node_pattern:GetTemplate(gend)]
end

local function AuxBlock (agroup, primary_node, make, is_export, params)
	local choice = table_view_patterns.Listbox(agroup, GetListboxOpts(params.get_text or DefGetText))
	local choice_text = params.choice_text or theme.ChoiceDefaultString()
	local ctext = display.newText(agroup, choice_text, 0, 0, theme.ChoiceTextParams())

	choice.y = ctext.y -- Hmm, was this significant? :P

	params.add_choices(choice)

	if not choice:GetSelection() then
		choice:Select(1)
	end

	local sep = theme.BlockAttachmentBoxSeparationOffset()

	if is_export then
		return choice, box_layout.Arrange(false, sep, primary_node, ctext, choice, make) -- TODO
	else
		return choice, box_layout.Arrange(false, sep, ctext, choice, make, primary_node)
	end
end

--- DOCME
function M:BlockAttachmentBox (group, id, info, is_export, params)
	local agroup, make, primary_node = MakeBoxObjects(group, id)
	local choice, lo, ro = AuxBlock(agroup, primary_node, make, is_export, params)
	local box = MakeBox(self, agroup, make, primary_node, lo, ro)

	box.m_choice, box.m_is_export, box.m_style = choice, is_export, "block"
	box.m_group_info = info -- n.b. calling code makes no more use of this

	return GatherAndAddRows(self, box, id, info)
end

--- DOCME
function M.Unload ()
	ListboxOpts = nil
end

return M