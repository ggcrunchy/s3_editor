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
local random = math.random
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

local function Shift (items, shift, a, b, is_array)
	local delta = shift > 0 and 1 or -1

	for i = a, b, delta do
		local instance = is_array and items[i].m_instance

		if instance then
			common.SetLabel(instance, common.GetLabel(instance) + delta)
		end

		items[i].y = items[i + shift].y
	end
end

local function RemoveRow (list, row, n, is_array)
	local last = row * n

	Shift(list, -n, list.numChildren, last + 1, is_array)
	RemoveRange(list, last, n)
end

local Delete = touch.TouchHelperFunc(function(_, button)
	local fixed = button.parent
	local agroup = fixed.parent
	local row, items, nodes = button.m_row, agroup.items, agroup.nodes
	local nfixed, nnodes = fixed.numChildren, nodes.numChildren
	local neach = items.numChildren / nnodes -- only one node per row, but maybe more than one item
	local base = (row - 1) * neach

	for i = 1, neach do
		local instance = items[base + i].m_instance

		if instance then
			common.RemoveInstance(button.m_object, instance)
		end
	end

	RemoveRow(items, row, neach, items.m_is_array)
	RemoveRow(nodes, row, 1)
	RemoveRange(fixed, nfixed, nfixed / nnodes) -- as above, in case more than one fixed object per row

	common.Dirty()
end)

local function GetFromItemInfo (items, fi, ti, n, is_array)
	for i = 0, n - 1 do
		local from_instance = is_array and items[ti - i].m_instance

		if from_instance then
			items[fi - i].m_old_index = common.GetLabel(from_instance)
		end

		items[fi - i].m_y = items[ti - i].y
	end
end

local function SetToItemInfo (items, _, ti, n)
	for i = 0, n - 1 do
		local item = items[ti - i]

		if item.m_old_index then
			common.SetLabel(item.m_instance, item.m_old_index)
		end

		item.y, item.m_old_index, item.m_y = item.m_y
	end
end

local function AuxMoveRow (items, stash, fi, ti, n, is_array)
	GetFromItemInfo(items, fi, ti, n, is_array)

	local tpos = ti - n + 1

	if fi < ti then
		Shift(items, -n, ti, fi + 1, is_array)
	else
		Shift(items, n, tpos, fi - n, is_array)
	end

	for i = 0, n - 1 do -- to avoid having to reason about how insert() works with elements already in the group,
						-- temporarily put them somewhere else, in reverse order...
		stash:insert(items[fi - i])
	end

	for i = 1, n do -- ...then stitch them back in where they belong
		items:insert(tpos, stash[stash.numChildren - n + i])
	end

	SetToItemInfo(items, fi, ti, n)
end

local function MoveRow (items, nodes, from, to)
	if from ~= to then
		local n = items.numChildren / nodes.numChildren -- only one node per row, but maybe more than one item
		local fi, ti = from * n, to * n

		AuxMoveRow(items, nodes, fi, ti, n, items.m_is_array)
		AuxMoveRow(nodes, items, from, to, 1)
	end
end

local function FindRow (drag_box, box, nodes)
	local row = array_index.FitToSlot(drag_box.y, box.y + box.height / 2, drag_box.height)

	return (row >= 1 and row <= nodes.numChildren) and row
end

local function GetBox (group)
	return group[1]
end

local Move = touch.TouchHelperFunc(function(event, ibox)
	local items = ibox.parent
	local box = GetBox(items.parent)
	local drag_box = box.m_drag

	drag_box.x, drag_box.y = ibox.x, ibox.y
	drag_box.isVisible = true

	ibox.m_dragy, ibox.m_from = ibox.y - event.y, FindRow(drag_box, box, items.parent.nodes)
end, function(event, ibox)
	local items = ibox.parent

	GetBox(items.parent).m_drag.y = ibox.m_dragy + event.y
end, function(_, ibox)
	local items = ibox.parent
	local box = GetBox(items.parent)
	local drag_box, nodes = box.m_drag, items.parent.nodes
	local row = FindRow(drag_box, box, items, nodes)

	if row then
		MoveRow(items, nodes, ibox.m_from, row)
	end

	drag_box.isVisible = false
end)

local function IndexFromInstance (instance)
	return tonumber(common.GetLabel(instance))
end

local function AssembleArray (tag_db, tag, sub, instances)
	local arr

	for i = 1, #(instances or "") do
		local instance = instances[i]

		if tag_db:GetTemplate(tag, instance) == sub then
			arr = arr or {}
			arr[IndexFromInstance(instance)] = instance
		end
	end

	return arr
end

local EditOpts = {
	font = theme.AttachmentTextEditFont(), size = theme.AttachmentTextEditSize(),

	get_editable_text = function(editable)
		return common.GetLabel(editable.m_instance)
	end,

	set_editable_text = function(editable, text)
		common.SetLabel(editable.m_instance, text)

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

local function Mixed (agroup, SUB, primary_node, add, is_export)
	local get_text, choice = SUB.get_text or DefGetText
	local opts, ctext = GetListboxOpts(get_text), SUB.choice_text or "Choice:" -- TODO: theme

	choice = table_view_patterns.Listbox(agroup, opts)
	ctext = display.newText(agroup, ctext, 0, 0, native.systemFont, 15) -- TODO: theme
	choice.y = ctext.y -- Hmm, was this meant to be important? :P

	SUB.add_choices(choice)

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





local function GEN_NAME (tag_db, tag, object, choice, set_style)
	local gend

	if set_style ~= "mixed" then
		gend = tag_db:Instantiate(tag, sub)
	else
		gend = tag_db:Instantiate(tag, choice:GetSelectionData())
	end

	common.AddInstance(object, instance) -- TODO

	if not set_style then
		common.SetLabel(instance, n) -- TODO
	end

	common.Dirty() -- TODO

	return gend
end

local function IBOX (box, agroup, n, w, set_style)
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

local function ADD (box, generated_name)
	local agroup, is_export, set_style = box.parent, box.m_is_export, box.m_set_style
	local n, w = agroup.nodes.numChildren, box.width + (set_style and 25 or 0) -- TODO: theme

	generated_name = generated_name or GEN_NAME(tag_db, tag, object, choice, set_style)

	local ibox = IBOX(box, agroup, n, w, set_style)
	local node, hw = theme.Node(agroup.nodes), w / 2

	node.x = box.x + (is_export and hw or -hw)
	node.y = ibox.y

	local delete = theme.DeleteButton(agroup.fixed, ibox)

	delete:addEventListener("touch", Delete)

	delete.x = box.x + (is_export and -hw or hw)

	delete.m_object, delete.m_row = object, n

	if set_style then
		local text = editable.Editable_XY(agroup.items, ibox.x, ibox.y, EditOpts)

		text.m_instance = instance -- TODO

		text:SetText(common.GetLabel(instance) or "default") -- TODO

		if set_style == "mixed" then
			local atext = sub[tag_db:GetTemplate(tag, instance)]
			local about = display.newText(agroup.items, atext, 0, ibox.y, native.systemFont, 15) -- TODO: theme

			layout.PutLeftOf(about, text, -10) -- TODO: theme
		end
	else
		ibox.m_instance = instance

		display.newText(agroup.fixed, ("#%i"):format(n), ibox.x, ibox.y, native.systemFontBold, 10) -- TODO: theme
	end

	IntegrateNode(node, object, instance, is_export, box.m_knot_list_index)
end


local function Add (button)
--	GetBox(button.parent):m_add()
	-- GEN_NAME(tag_db, tag, object, choice, set_style)
	ADD(GetBox(button.parent), nil)
end

local function AddSubGroups (agroup, is_array)
	agroup.items, agroup.fixed, agroup.nodes = display.newGroup(), display.newGroup(), display.newGroup()

	agroup:insert(agroup.items)
	agroup:insert(agroup.fixed)
	agroup:insert(agroup.nodes)

	agroup.items.m_is_array = is_array
end

--- DOCME
function M:AttachmentBox (group, object, tag_db, tag, sub, is_export, set_style)
	-- TODO: object is probably "id", in which case tag_db and tag irrelevant
	-- sub will be "name", then... maybe export-ness can be discovered too?
	-- maybe could even just break up into two functions soon, one for "mixed" and another for rest
	local agroup, choice = display.newGroup()

	group:insert(agroup)

	local add, primary_node, lo, ro = button.Button(agroup, "4.25%", "4%", Add, "+"), theme.Node(agroup) -- TODO: theme

	if set_style ~= "mixed" then
		lo, ro = box_layout.Arrange(not is_export, 10, primary_node, add) -- TODO: theme
	else
		choice, lo, ro = Mixed(agroup, sub, primary_node, add, is_export)
	end

	local w, midx = box_layout.GetLineWidth(lo, ro, "want_middle")
	local box = self:AddBox(agroup, w + 25, add.height + 15) -- TODO: theme

	box.primary, box.x = primary_node, agroup:contentToLocal(midx, 0)

	AddSubGroups(agroup, not set_style)

	box.m_is_export = is_export
	box.m_set_style = set_style
	-- TODO: object, choice, etc?

--	box.m_add = ADD -- N.B. At this point doesn't seem to need to be a member... just forward-declare it

	box.GetNodesGroup = GetNodesGroup

	local instances = common.GetInstances(object)

	if set_style then
		for i = 1, #(instances or "") do
			local instance = instances[i]
			local template = tag_db:GetTemplate(tag, instance)

			if set_style ~= "mixed" then
				if template == sub then
				--	box:m_add(instance)
					ADD(box, instance)
				end
			elseif sub[template] then
				--box:m_add(instance)
				ADD(box, instance)
			end
		end
	else
		local arr = AssembleArray(tag_db, tag, sub, instances) -- TODO: could just ADD() along the way...

		for i = 1, #(arr or "") do
		--	box:m_add(arr[i])
			ADD(box, arr[i])
		end
	end

	return box
end

--- DOCME
function M.Unload ()
	ListboxOpts = nil
end

return M