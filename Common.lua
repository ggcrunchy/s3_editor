--- Components shared throughout the editor.

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
local next = next
local pairs = pairs
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local config = require("config.Editor")
local layout = require("solar2d_ui.utils.layout")
local menu = require("solar2d_ui.widgets.menu")
local object_vars = require("config.ObjectVariables")
local touch = require("solar2d_ui.utils.touch")

-- Classes --
--[[
local Links = require("tektite_base_classes.Link.Links")
local Tags = require("tektite_base_classes.Link.Tags")
]]
-- Solar2D globals --
local display = display
local native = native
local Runtime = Runtime
local timer = timer

-- Cached module references --
local _AlertNameWatchers_
local _AttachLinkInfo_
local _BindRepAndValues_
local _DraggableStarter_
local _DraggableFinisher_
local _SetLabel_
local _StashAndFrame_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.AddCommandsBar (params)
	local cgroup, back, bar_height, y = _DraggableStarter_(params)
	local context, back_height, h, prev = params.help_context, back.height - bar_height, 0

	for i = 1, #params, 3 + (context and 1 or 0) do
		local text, dparams, str = params[i], params[i + 1]

		if text then
			str = display.newText(cgroup, text, 0, y, native.systemFont, 16)
		end

		dparams.group, dparams.heading_height, dparams.size = cgroup, back_height - 8, 12

		local dropdown = menu[dparams.is_menu and "Menu" or "Dropdown"](dparams)

		if str then
			layout.PutRightOf(str, prev, 5)
		end

		layout.PutRightOf(dropdown, str or prev, 5)

		local stash = _StashAndFrame_(cgroup, dropdown, y)

		if context then
			context:Add(dropdown, params[i + 3])
		end

		h = max(h, dropdown.height)

		dropdown:RestoreDropdowns(stash)

		cgroup[params[i + 2]], prev = dropdown, dropdown
	end

	return _DraggableFinisher_(params, cgroup, back, bar_height, prev, params.top or "45%", params.title), back.height
end

local Instances

--- DOCME
function M.AddInstance (object, instance)
	Instances = Instances or {}

	local ilist = Instances[object] or {}

	Instances[object], ilist[#ilist + 1] = ilist, instance
end

-- List of objects that care about level name --
local WatchingName

--- DOCME
function M.AlertNameWatchers ()
	for _, watcher in ipairs(WatchingName) do
		watcher()
	end
end

--
function M.AttachLinkInfo (object, info)
	local old_info = object.m_link_info

	object.m_link_info = info

	return old_info
end

-- --
local RepToValues, ValuesToRep

--
local function BackBind (values, rep)
	if values ~= nil then
		ValuesToRep[values] = rep
	end
end

--- DOCME
function M.BindRepAndValues (rep, values)
	local prev

	if rep then
		prev = RepToValues[rep]

		BackBind(prev, nil)
		BackBind(values, rep)

		RepToValues[rep] = values
	end

	return prev
end

-- --
local SessionLinks

-- --
local LinkInfo

--- DOCME
function M.BindRepAndValuesWithTag (rep, values, tag, dialog)
	if tag then
		_BindRepAndValues_(rep, values)

		SessionLinks:SetTag(rep, tag)

		if dialog then
			LinkInfo = LinkInfo or {}

			dialog("get_link_info", values.type, LinkInfo, rep)

			if next(LinkInfo, nil) then
				_AttachLinkInfo_(rep, LinkInfo)

				LinkInfo = nil
			end
		end
	end
end

-- --
local Labels

-- --
local LinkGroupings

-- --
local Positions

--- Cleans up various state used pervasively by the editor.
function M.CleanUp ()
	timer.cancel(SessionLinks.cleanup)

	Instances, Labels, LinkGroupings, Positions, RepToValues, SessionLinks, ValuesToRep, WatchingName = nil
end

-- Are there changes in need of saving? --
local IsDirty

-- Is the working level game-ready? --
local IsVerified

--- Sets the editor dirty state, if clear, and updates dirty-related features.
--
-- The working level must also be re-verified.
-- @see IsDirty, IsVerified, Undirty, Verify
function M.Dirty ()
	IsDirty, IsVerified = true, false

	_AlertNameWatchers_()
end

local TitleOffset = 2

--- DOCME
function M.DraggableFinisher (params, cgroup, back, bar_height, prev, top, title)
	local w = max(layout.RightOf(prev, 5), params and params.full_width or 0)

	if title then
		local offset = params and params.title_offset or TitleOffset
		local str = display.newText(cgroup, title, .5 * w, .5 * bar_height + offset, native.systemFontBold, 14)

		if str.width > w then
			w = str.width + 20
			str.x = .5 * w
		end

		if params and params.with_title then
			params.with_title(str)
		end
	end

	back.width = w

	layout.CenterAtX(cgroup, "50%")
	layout.TopAlignWith(cgroup, top)

	touch.Spoof(cgroup)

	return cgroup
end

-- --
local DragTouch = touch.DragParentTouch{ to_front = true }

-- --
local BackHeight, BarHeight = 30, 16

--- DOCME
function M.DraggableStarter (params)
	local bar_height = params and params.bar_height or BarHeight
	local cgroup, h = display.newGroup(), BackHeight + bar_height
	local rtype = (params and params.not_rounded) and "newRect" or "newRoundedRect"
	local back = display[rtype](cgroup, 0, .5 * h, 1, h, 5)

	if not (params and params.not_draggable) then
		back:addEventListener("touch", DragTouch)
	end

	back:setFillColor(.5)
	back:setStrokeColor(.6, .9)

	back.anchorX, back.x = 0, 0
	back.strokeWidth = 2

	return cgroup, back, bar_height, h - .5 * BackHeight
end

-- How many columns wide and how many rows tall is the working level? --
local NCols, NRows

--- Getter.
-- @treturn uint Number of columns in working level...
-- @treturn uint ...and number of rows.
function M.GetDims ()
	return NCols, NRows
end

--- DOCME
function M.GetInstances (object, how)
	local ilist = Instances and Instances[object]

	if how == "copy" and ilist then
		local into = {}

		for _, instance in ipairs(ilist) do
			into[#into + 1] = instance
		end

		return into
	end

	return ilist
end

--- DOCME
function M.GetPositions (object)
	return Positions and Positions[object]
end

--- Getter.
-- @string name Name to label, e.g. an instanced sublink.
-- @treturn ?|string|nil Current label, or **nil** if none is assigned.
function M.GetLabel (name)
	return Labels and Labels[name]
end

--- DOCME
function M.GetLinkGrouping (tname)
	return LinkGroupings and LinkGroupings[tname]
end

--- DOCME
function M.GetLinks ()
	return SessionLinks
end

--- DOCME
-- @ptable values
-- @treturn pobject O
function M.GetRepFromValues (values)
	return ValuesToRep[values]
end

--
local function PairSublinks (sub_links, t1, name1, t2, name2)
	for k in adaptive.IterSet(t1) do
		sub_links[k] = name2
	end

	for k in adaptive.IterSet(t2) do
		sub_links[k] = name1
	end
end

local PushFuncs = {}

local function LimitToOneLink (object, _, sub, _, links)
	return not links:HasLinks(object, sub:GetName())
end

local function PairSublinksMulti (sub_links, t1, push, t2, pull)
	for k in adaptive.IterSet(t1) do
		sub_links[k] = pull
	end

	for k in adaptive.IterSet(t2) do
		local pfunc = push

		if k:sub(-1) == "+" then -- allow more links?
			k = k:sub(1, -2)
		elseif not PushFuncs[pfunc] then -- else impose a one-link limit as well
			local augmented = { link_to = adaptive.Append(pfunc, LimitToOneLink) }

			PushFuncs[pfunc], pfunc = augmented, augmented
		else
			pfunc = PushFuncs[pfunc]
		end

		sub_links[k] = pfunc
	end
end

-- --
local Properties = object_vars.properties

--
local function PropertyPairs (sub_links, t1, t2)
	for name, prop in pairs(Properties) do
		PairSublinksMulti(sub_links, t1 and t1[name], prop.push, t2 and t2[name], prop.pull)
	end

	return sub_links
end

--- DOCME
-- @param etype
-- @callable on_editor_event
-- @treturn ?string X
function M.GetTag (etype, on_editor_event)
	local tname = on_editor_event(etype, "get_tag")
	local tag_db = SessionLinks:GetTagDatabase()

	if tname and not tag_db:Exists(tname) then
		local topts, ret1, ret2, ret3, ret4 = on_editor_event(etype, "new_tag")

		if topts == "sources_and_targets" then
			local sub_links = {}

			PairSublinks(sub_links, ret1, "event_source", ret2, "event_target")

			topts = { sub_links = PropertyPairs(sub_links, ret3, ret4) }
		elseif topts == "properties" then
			topts = { sub_links = PropertyPairs({}, ret1, ret2) }
		end

		local lg = on_editor_event(etype, "get_link_grouping")

		if lg then
			LinkGroupings = LinkGroupings or {}
			LinkGroupings[tname] = lg
		end

		tag_db:New(tname, topts)
	end

	return tname
end

-- --
local TopHeight

--- DOCME
function M.GetTopHeight ()
	return TopHeight
end

--- DOCME
-- @pobject rep
-- @treturn table T
function M.GetValuesFromRep (rep)
	return RepToValues[rep]
end

-- Common "current selection" position --
local CurrentX, CurrentY

-- Last mode, if any --
local Mode

--- Initializes various state used pervasively by the editor.
-- @uint ncols How many columns will be in the working level...
-- @uint nrows ...and how many rows?
function M.Init (ncols, nrows)
	NCols, NRows, Mode, CurrentX, CurrentY = ncols, nrows
	RepToValues, ValuesToRep, IsDirty, IsVerified = {}, {}, false, false
	SessionLinks = Links(Tags(), function(object)
		return object.parent
	end)

	WatchingName = {}

	-- Do periodic cleanup of links.
	local index = 1

	SessionLinks.cleanup = timer.performWithDelay(50, function()
		index = SessionLinks:CleanUp(index)
	end, 0)

	Runtime:dispatchEvent{ name = "editor_session_init", ncols = ncols, nrows = nrows, w = config.w, h = config.h }
end

--- Predicate.
-- @treturn boolean Are there unsaved changes to the working level?
-- @see Dirty, Undirty
function M.IsDirty ()
	return IsDirty
end

--- Predicate.
-- @treturn boolean Is the working level game-ready?
-- @see Verify
function M.IsVerified ()
	return IsVerified
end

-- DOCME
function M.NewScreenSizeContainer (group, items, opts)
	local cont = display.newContainer(display.contentWidth, display.contentHeight - TopHeight)

	group:insert(cont)

	--
	local cw, ch, offset, x0, y0 = cont.width, cont.height, opts and opts.offset

	cont:insert(items)

	x0, y0 = -cw / 2, -ch / 2

	if offset then
		offset.x, offset.y = 0, 0
	end

	items:translate(x0, y0)

	if opts and opts.layers then
		for _, layer in ipairs(opts.layers) do
			cont:insert(layer)
			layer:translate(x0, y0 - TopHeight)
		end
	end

	layout.LeftAlignWith(cont, 0)
	layout.TopAlignWith(cont, TopHeight)

	-- Draggable thing...
	local drag = display.newRect(group, cont.x, cont.y, cw, ch)

	drag:addEventListener("touch", touch.DragViewTouch(items, {
		x0 = "cur", y0 = "cur", xclamp = "view_max", yclamp = "view_max",
		dx = opts and opts.dx, dy = opts and opts.dy,

		on_post_move = offset and function(ig)
			offset.x, offset.y = x0 - ig.x, y0 - ig.y
		end
	}))

	drag.isHitTestable, drag.isVisible = true, false
-- ^^^ TODO: if not large enough, nothing
	return cont, drag
end

--- DOCME
function M.RemoveInstance (object, instance)
	local ilist = Instances and Instances[object]

	if instance ~= "all" then
		local n = #ilist

		for i = 1, n do
			if ilist[i] == instance then
				_SetLabel_(instance, nil)

				ilist[i] = ilist[n]
				ilist[n] = nil

				break
			end
		end
	elseif ilist then
		for _, instance in ipairs(ilist) do
			_SetLabel_(instance, nil)
		end

		Instances[object] = nil
	end
end

--- Attach a label to a name, e.g. to attach user-defined information.
-- @string name Name to label.
-- @tparam ?|string|nil Label to assign, or **nil** to remove the label.
function M.SetLabel (name, label)
	if label then
		Labels = Labels or {}
		Labels[name] = label
	elseif Labels then
		Labels[name] = nil
	end
end

--- DOCME
function M.SetPositions (object, positions)
	if Positions or positions then
		Positions = Positions or {}
		Positions[object] = positions
	end
end

--- DOCME
function M.SetTopHeight (height)
	TopHeight = height
end

--- Shows or hides the current selection widget. As a convenience, the last position of a
-- widget when hidden is applied to the next widget shown.
-- @pobject current Widget to show or hide.
-- @bool show If true, show the current item.
function M.ShowCurrent (current, show)
	if current.isVisible ~= not not show then
		local mode, mode_list = Mode, current.m_mode

		Mode = nil

		if mode_list then
			if not show then
				Mode = mode_list:GetSelection("text")
			elseif mode and type(show) == "table" then
				mode_list:Select(mode, "no_op")
			end
		end

		if not show then
			CurrentX, CurrentY = current.x, current.y
		elseif CurrentX and CurrentY then
			current.x, current.y = CurrentX, CurrentY
		end

		current.isVisible = show
	end
end

--- DOCME
function M.StashAndFrame (cgroup, dropdown, y)
	local stash = dropdown:StashDropdowns()

	layout.CenterAtY(dropdown, y)

	local border = display.newRect(cgroup, 0, y, dropdown.width, dropdown.height)

	layout.CenterAtX(border, layout.CenterX(dropdown))

	border:setFillColor(0, 0)
	border:setStrokeColor(.3)

	border.strokeWidth = 1

	return stash
end

--- Clears the editor dirty state, if set, and updates dirty-related features.
-- @see Dirty, IsDirty
function M.Undirty ()
	IsDirty = false

	_AlertNameWatchers_()
end

--- DOCME
function M.WatchName (func)
	WatchingName[#WatchingName + 1] = func
end

--- Sets the editor verified state, if clear, and updates verification-related features.
-- @see IsVerified
function M.Verify ()
--	M.FadeButton("Verify", not IsVerified, .4)

	IsVerified = true
end

_AlertNameWatchers_ = M.AlertNameWatchers
_AttachLinkInfo_ = M.AttachLinkInfo
_BindRepAndValues_ = M.BindRepAndValues
_DraggableStarter_ = M.DraggableStarter
_DraggableFinisher_ = M.DraggableFinisher
_SetLabel_ = M.SetLabel
_StashAndFrame_ = M.StashAndFrame

return M