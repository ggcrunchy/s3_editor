--- Map editor scene.
--
-- In this scene, users can edit and test "work in progress" levels, and build levels
-- into a form loadable by @{solar2d_boilerplate.game.loop.LoadLevel}.
--
-- The scene expects event.params == { main = { _cols_, _rows_ }**[**, is_loading = _name_
-- **]** }, where _cols_ and _rows_ are the tile-wise size of the level. When loading a
-- level, you must also provide _name_, which corresponds to the _name_ argument in the
-- level-related functions in @{solar2d_utils.persistence} (_wip_ == **true**).
--
-- The editor is broken up into several "views", each isolating specific features of the
-- level. The bulk of the editor logic is implemented in these views' modules, with common
-- building blocks in @{s3_editor.Common} and @{s3_editor.Dialog}. View-agnostic operations
-- are found in @{s3_editor.Ops} and used to implement various core behaviors in this scene.
--
-- @todo Mention unloaded; also load_level_wip, save_level_wip, level_wip_opened, level_wip_closed events...

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
local pairs = pairs

-- Load the editor pieces lazily to avoid a hard stall.
local old_require, lazy_require = require, require("tektite_core.require_ex").Lazy

require = lazy_require

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local button = require("solar2d_ui.widgets.button")
local common = require("s3_editor.Common")
local editable = require("solar2d_ui.patterns.editable")
local editor_strings = require("config.EditorStrings")
local grid = require("s3_editor.Grid")
local help = require("s3_editor.Help")
local layout = require("solar2d_ui.utils.layout")
local object_vars = require("config.ObjectVariables")
local ops = require("s3_editor.Ops")
local persistence = require("solar2d_utils.persistence")
local prompts = require("solar2d_ui.patterns.prompts")
local require_ex = require("tektite_core.require_ex")
local strings = require("tektite_core.var.strings")

-- Solar2D globals --
local display = display
local native = native
local Runtime = Runtime

-- Solar2D modules --
local composer = require("composer")

--
--
--

-- Map editor scene --
local Scene = composer.newScene()

-- Create Scene --
function Scene:create ()
	persistence.AddSaveFunc(print) -- TODO: make an option somewhere?

	local handle_key = composer.getVariable("handle_key")

	editable.SetKeyLogic(function(handler)
		handle_key:Push(handler)
	end, function()
		handle_key:Pop()
	end)
end

Scene:addEventListener("create")

-- Current editor view --
local Current

-- View switching and related FSM logic
local function SetCurrent (view)
	if Current ~= view then
		if Current then
			Current.Exit(Scene.view)
		end

		Current = view

		if Current then
			Current.Enter(Scene.view)
		end
	end
end

-- List of editor views --
local EditorView

local function SetCurrentFromMenu (event)
	SetCurrent(EditorView[event.text])

	event.target:toFront()
end

-- Names of editor views --
local Names, Prefix, Categories = require_ex.GetNames("config.EditorViews")

local MenuColumns, CurrentHeading = {}

for _, name in ipairs(Names) do
	local category = Categories[name]

	if category then
		if category ~= CurrentHeading then
			MenuColumns[#MenuColumns + 1] = category
			MenuColumns[#MenuColumns + 1], CurrentHeading = {}, category
		end

		local clist = MenuColumns[#MenuColumns]

		clist[#clist + 1] = name
	else
		MenuColumns[#MenuColumns + 1] = name
	end
end

-- Scene listener: handles quit requests
local function WantsToGoBack ()
	prompts.DoActionThenProceed{
		choices = "save_and_quit",
		needs_doing = common.IsDirty,
		action = ops.Save_FollowUp,
		follow_up = ops.Quit
	}
end

-- --
local Actions = { "Save", "Verify", "Build", "Test" }

local BarHeight = 20

local function AddCloseButton (group, help_context)
	local wtgb = composer.getVariable("WantsToGoBack")
	local close = button.Button_XY(group, 0, .5 * BarHeight, 2 * BarHeight, BarHeight - 6, wtgb, {
		text = "x", skin = "small_text_button"
	})

	layout.RightAlignWith(close, display.contentWidth - 5)

	help_context:Add(close, editor_strings("editor_close"))
end

local function AddHelpIcon (group)
	local hgroup, y = display.newGroup(), .5 * BarHeight
	local help_icon = display.newCircle(hgroup, 15, y, 8)

	group:insert(hgroup)
	help_icon:addEventListener("touch", help.TouchFunc)
	help_icon:setFillColor(0, 0, .9)
	help_icon:setStrokeColor(.7, 0, .3, .9)

	help_icon.strokeWidth = 1

	display.newText(hgroup, "?", help_icon.x, y, native.systemFontBold, 10)
end

local WideString = "MMMMMMMMMMMMMMM" -- allocate space for the visible part of the level name, using wider character

local function AddMenu (view)
	local help_context = help.NewContext()
	local commands, h = common.AddCommandsBar{
		not_draggable = true, not_rounded = true,
		help_context = help_context, title = WideString,
		bar_height = 20, title_offset = 2, full_width = display.contentWidth, top = 0,

		with_title = function(title)
			title.m_num_chars = #title.text

			help_context:Add(title, editor_strings("editor_level_name"))

			AddHelpIcon(title.parent)
			AddCloseButton(title.parent, help_context)

			local function watch_name ()
				local n, name, star = title.m_num_chars, ops.GetLevelName() or "Untitled", common.IsDirty() and " *" or ""

				if #star > 0 then
					n = n - 2
				end

				if #name > n then
					name = name:sub(1, n - 3) .. "..."
				end

				title.text = name .. star
			end

			watch_name()

			common.WatchName(watch_name)
		end,

		false, {
			columns = { "Actions", Actions }, is_menu = true,
			column_width = 95, heading_height = 18, size = 12
		}, "m_actions", editor_strings("editor_actions"),

		"Views:", {
			columns = MenuColumns, is_menu = true,
			column_width = 95, heading_height = 18, size = 12,

			get_text = function(name)
				return strings.SplitIntoWords(name, "on_pattern")
			end
		}, "m_views", editor_strings("editor_views")
	}

	commands.m_actions:addEventListener("menu_item", function(event)
		ops[event.text]()
	end)
	commands.m_views:addEventListener("menu_item", SetCurrentFromMenu)

	view:insert(commands)
	help_context:Register()

	common.SetTopHeight(h)

	return commands
end

-- Show Scene --
function Scene:show (event)
	if event.phase == "did" then
		composer.getVariable("wants_to_go_back"):Push(WantsToGoBack)

		-- We may enter the scene one of two ways: from the editor setup menu, in which case
		-- we use the provided scene parameters; else returning from a test, where we must
		-- reconstruct the state from information we left behind.
		local came_from, params = composer.getSceneName("previous") or ""

		if came_from:ends(".Level") then
			params = ops.Restore()
		else
			params = event.params
		end

		-- Initialize systems.
		common.Init(params.main[1], params.main[2])
		help.Init()
		ops.Init(self.view)

		--
		local tags = common.GetLinks():GetTagDatabase()

		for k, v in pairs{
			event_source = "event_target",
			event_target = "event_source"
		} do
			tags:ImplyInterface(k, v)
		end

		for _, prop in pairs(object_vars.properties) do
			tags:ImplyInterface(prop.pull, prop.push)
			tags:ImplyInterface(prop.push, prop.pull)
		end

		if object_vars.implied_by then
			for from, props in pairs(object_vars.implied_by) do
				for _, to in adaptive.IterArray(props) do
					tags:ImplyInterface(from, to)
					tags:ImplyInterface(to, from)
				end
			end
		end

		-- Install the views and load any scene.
		local commands = AddMenu(self.view)

		grid.Init(self.view)

		for _, view in pairs(EditorView) do
			view.Load(self.view)
		end

		ops.TryToLoad(params)

		-- Trigger the default view and announce readiness.
		commands:toFront()
		commands.m_views:Select("player")

		ops.MakeReady()
	end
end

Scene:addEventListener("show")

-- Hide Scene --
function Scene:hide (event)
	if event.phase == "did" then
		composer.getVariable("wants_to_go_back"):Pop()

		SetCurrent(nil)

		for _, view in pairs(EditorView) do
			view.Unload()
		end

		ops.CleanUp()
		grid.CleanUp()
		help.CleanUp()
		common.CleanUp()

		for i = self.view.numChildren, 1, -1 do
			self.view:remove(i)
		end

		Runtime:dispatchEvent{ name = "level_wip_closed" }
	end
end

Scene:addEventListener("hide")

-- Finally, install the editor views and restore old loading.
EditorView = require_ex.DoList_Names(Names, Prefix)

require = old_require

return Scene