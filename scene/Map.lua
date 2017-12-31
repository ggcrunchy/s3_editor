--- Map editor scene.
--
-- In this scene, users can edit and test "work in progress" levels, and build levels
-- into a form loadable by @{corona_boilerplate.game.loop.LoadLevel}.
--
-- The scene expects event.params == { main = { _cols_, _rows_ }**[**, is_loading = _name_
-- **]** }, where _cols_ and _rows_ are the tile-wise size of the level. When loading a
-- level, you must also provide _name_, which corresponds to the _name_ argument in the
-- level-related functions in @{corona_utils.persistence} (_wip_ == **true**).
--
-- The editor is broken up into several "views", each isolating specific features of the
-- level. The bulk of the editor logic is implemented in these views' modules, with common
-- building blocks in @{s3_editor.Common} and @{s3_editor.Dialog}. View-agnostic operations
-- are found in @{s3_editor.Ops} and used to implement various core behaviors in this scene.
--
-- @todo Mention enter_menus; also load_level_wip, save_level_wip, level_wip_opened, level_wip_closed events...

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

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local button = require("corona_ui.widgets.button")
local common = require("s3_editor.Common")
local grid = require("s3_editor.Grid")
local editor_strings = require("config.EditorStrings")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")
local menu = require("corona_ui.widgets.menu")
local object_vars = require("config.ObjectVariables")
local ops = require("s3_editor.Ops")
local persistence = require("corona_utils.persistence")
local prompts = require("corona_ui.patterns.prompts")
local require_ex = require("tektite_core.require_ex")
local scenes = require("corona_utils.scenes")
local strings = require("tektite_core.var.strings")

-- Corona globals --
local display = display
local native = native
local Runtime = Runtime

-- Corona modules --
local composer = require("composer")

-- Map editor scene --
local Scene = composer.newScene()

-- Create Scene --
function Scene:create ()
	scenes.Alias("Editor")

	persistence.AddSaveFunc(print) -- TODO: make an option somewhere?
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
local function Listen (what)
	if what == "message:wants_to_go_back" then
		prompts.DoActionThenProceed{
			choices = "save_and_quit",
			needs_doing = common.IsDirty,
			action = ops.Save_FollowUp,
			follow_up = ops.Quit
		}
	end
end

-- --
local HelpContext

-- --
local Actions = { "Test", "Build", "Verify", "Save" }

local function AddCommands (view)
	local cgroup, back, bar, y = common.DraggableStarter()
	local hgroup = display.newGroup()
	local help_icon = display.newCircle(hgroup, 10, y + 3, 8)

	cgroup:insert(hgroup)
	help_icon:addEventListener("touch", help.TouchFunc)
	help_icon:setFillColor(0, 0, .9)
	help_icon:setStrokeColor(.7, 0, .3, .9)

	help_icon.strokeWidth = 1

	display.newText(hgroup, "?", help_icon.x, help_icon.y, native.systemFontBold, 10)

	local about = display.newText(cgroup, "MMMMMMMMMMMMMMM", 0, help_icon.y, native.systemFont, 12) -- allocate space for text

	about.m_num_chars = #about.text

	layout.PutRightOf(about, help_icon, 5)

	local selector = menu.Menu{
		group = cgroup, columns = { "Actions", Actions },
		column_width = 95, heading_height = 18, size = 12
	}

	view:insert(cgroup)

	layout.PutRightOf(selector, about, 5)

	local stash = common.StashAndFrame(cgroup, selector, help_icon.y)

	selector:addEventListener("menu_item", function(event)
		ops[event.text]()
	end)

	selector:RestoreDropdowns(stash)

	common.DraggableFinisher(cgroup, back, bar, selector, "87.5%", "Commands")

	local close = button.Button_XY(cgroup, 0, bar.y, 2 * bar.height - 5, bar.height - 6, scenes.WantsToGoBack, {
		text = "x", skin = "small_text_button"
	})

	layout.RightAlignWith(close, bar, -5)

	local function watch_name ()
		local n, name, star = about.m_num_chars, ops.GetLevelName() or "Untitled level", common.IsDirty() and " *" or ""

		if #star > 0 then
			n = n - 2
		end

		if #name > n then
			name = name:sub(n - 3) .. "..."
		end

		about.text = name .. star
	end

	watch_name()

	common.WatchName(watch_name)

	HelpContext:Add(back, editor_strings("commands"))
end

local function AddNavigation (view)
	local cgroup, back, bar, y = common.DraggableStarter()
	local vtext = display.newText(cgroup, "Views:", 0, y, native.systemFont, 16)
	local selector = menu.Menu{
		group = cgroup, columns = MenuColumns,
		column_width = 95, heading_height = 18, size = 12,

		get_text = function(name)
			return strings.SplitIntoWords(name, "on_pattern")
		end
	}

	view:insert(cgroup)

	layout.LeftAlignWith(vtext, 5)
	layout.PutRightOf(selector, vtext, 5)

	local stash = common.StashAndFrame(cgroup, selector, y + 3)

	selector:addEventListener("menu_item", SetCurrentFromMenu)
	selector:RestoreDropdowns(stash)
	selector:Select("player")

	common.DraggableFinisher(cgroup, back, bar, selector, "5%", "Navigation")

	HelpContext:Add(back, editor_strings("navigation"))
end

-- Show Scene --
function Scene:show (event)
	if event.phase == "did" then
		scenes.SetListenFunc(Listen)

		-- We may enter the scene one of two ways: from the editor setup menu, in which case
		-- we use the provided scene parameters; else returning from a test, where we must
		-- reconstruct the state from information we left behind.
		local params

		if scenes.ComingFrom() == "Level" then
			params = ops.Restore()
		else
			params = event.params
		end

		-- Initialize systems.
		common.Init(params.main[1], params.main[2])
		help.Init()
		grid.Init(self.view)
		ops.Init(self.view)

		HelpContext = help.NewContext()

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
		for _, view in pairs(EditorView) do
			view.Load(self.view)
		end

		ops.TryToLoad(params)

		-- Install dialogs, trigger the default view, and announce readiness.
		AddCommands(self.view)
		AddNavigation(self.view)

		HelpContext:Register()

		ops.MakeReady()
	end
end

Scene:addEventListener("show")

-- Hide Scene --
function Scene:hide (event)
	if event.phase == "did" then
		scenes.SetListenFunc(nil)

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

		HelpContext = nil
	end
end

Scene:addEventListener("hide")

-- Finally, install the editor views.
EditorView = require_ex.DoList_Names(Names, Prefix)

return Scene