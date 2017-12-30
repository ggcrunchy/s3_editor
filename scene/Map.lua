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
local args = require("iterator_ops.args")
local button = require("corona_ui.widgets.button")
local common = require("s3_editor.Common")
local editor_config = require("config.Editor")
local events = require("s3_editor.Events")
local grid = require("s3_editor.Grid")
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
local timers = require("corona_utils.timers")

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

-- Non-level state to restore when returning from a test --
local RestoreState

-- Name used to store working version of level (WIP and build) in the database --
local TestLevelName = "?TEST?"

-- --
local HelpOpts = { isModal = true }

local function AddCommands (view, actions, funcs)
	local cgroup, back, bar, y = common.DraggableStarter()
	local help = display.newCircle(cgroup, 10, y + 3, 8)

	help:setFillColor(0, 0, .9)
	help:setStrokeColor(.7, 0, .3, .9)

	help.strokeWidth = 1

	display.newText(cgroup, "?", help.x, help.y, native.systemFontBold, 10)

	-- add funcs.Help logic...

	local about = display.newText(cgroup, "MMMMMMMMMMMMMMM", 0, help.y, native.systemFont, 12) -- allocate space for text

	about.m_num_chars = #about.text

	layout.PutRightOf(about, help, 5)

	local selector = menu.Menu{
		group = cgroup, columns = { "Actions", actions },
		column_width = 95, heading_height = 18, size = 12
	}

	view:insert(cgroup)

	local stash = selector:StashDropdowns()

	layout.CenterAtY(selector, help.y)
	layout.PutRightOf(selector, about, 5)

	selector:addEventListener("menu_item", function(event)
		funcs[event.text]()
	end)
	selector:RestoreDropdowns(stash)

	common.DraggableFinisher(cgroup, back, bar, selector, "30%", "Commands")
	layout.LeftAlignWith(cgroup, "5%")

	local close = button.Button_XY(cgroup, 0, bar.y, 2 * bar.height, bar.height - 4, scenes.WantsToGoBack, "x")

	layout.RightAlignWith(close, layout.RightOf(bar), -5)

	local function watch_name ()
		local n, name, star = about.m_num_chars, ops.GetLevelName() or "Untitled scene", common.IsDirty() and " *" or ""

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

	local stash = selector:StashDropdowns()

	layout.LeftAlignWith(vtext, 5)
	layout.CenterAtY(selector, y + 3)
	layout.PutRightOf(selector, vtext, 5)

	selector:addEventListener("menu_item", SetCurrentFromMenu)
	selector:RestoreDropdowns(stash)
	selector:Select("player")

	common.DraggableFinisher(cgroup, back, bar, selector, "5%", "Navigation")
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
			Runtime:dispatchEvent{ name = "enter_menus" }

			local _, data = persistence.LevelExists(TestLevelName, true)

			-- TODO: Doesn't exist? (Database failure?)

			params = persistence.Decode(data)

			params.is_loading = RestoreState.level_name
		else
			params = event.params
		end

		-- Load various master editor operations.
		local actions, funcs = {}, {}

		for _, func, text in args.ArgsByN(2,
			-- Test the level --
			function()
				local restore = { was_dirty = common.IsDirty(), common.GetDims() }

				ops.Verify()

				if common.IsVerified() then
					restore.level_name = ops.GetLevelName()

					-- The user might not want to save the changes being tested, thus we
					-- introduce an intermediate test level instead. The working version of
					-- the level might already be saved, however, in which case the upcoming
					-- save will be a no-op unless we manually dirty the level.
					common.Dirty()

					-- We save the test level: as a WIP, so we can restore up to our most recent
					-- changes; and as a build, which will be what we test. Both are loaded into
					-- the database, in order to take advantage of the loading machinery, under
					-- a reserved name (this will overwrite any existing entries). The levels are
					-- marked as temporary so they don't show up in enumerations.
					ops.SetTemp(true)
					ops.SetLevelName(TestLevelName)
					ops.Save()
					ops.Build()
					-- TODO?: ops.VerifyBuild(), e.g. to test for unmet link subscriptions
					ops.SetTemp(false)

					timers.Defer(function()
						local exists, data = persistence.LevelExists(TestLevelName)

						if exists then
							RestoreState = restore

							scenes.GoToScene{ name = editor_config.to_level, params = data, effect = "none" }
						else
							native.showAlert("Error!", "Failed to launch test level")

							-- Fix any inconsistent editor state.
							if restore.was_dirty then
								common.Dirty()
							end

							ops.SetLevelName(restore.level_name)
						end
					end)
				end
			end, "Test",

			-- Build a game-ready version of the level --
			ops.Build, "Build",

			-- Verify the game-ready integrity of the level --
			ops.Verify, "Verify",

			-- Save the working version of the level --
			ops.Save, "Save",

			-- Bring up a help overlay --
			function()
				composer.showOverlay("s3_editor.overlay.Help", HelpOpts)
			end, "Help"
		) do
			actions[#actions + 1], funcs[text] = text, func
		end

		-- Initialize systems.
		common.Init(params.main[1], params.main[2])
		help.Init()
		grid.Init(self.view)
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

		--[[
		help.AddHelp("Common", {
			Test = "Builds the level. If successful, launches the level in the game.",
			Build = "Verifies the scene. If is passes, builds it in game-loadable form.",
			Verify = "Checks the scene for errors that would prevent a build.",
			Save = "Saves the current work-in-progress scene."
		})
		help.AddHelp("Common", sidebar)
		]]

		-- Install the views.
		for _, view in pairs(EditorView) do
			view.Load(self.view)
		end

		-- If we are loading a level, set the working name and dispatch a load event. If we
		-- tested a new level, it may not have a name yet, but in that case a restore state
		-- tells us our pre-test WIP is available to reload. Usually the editor state should
		-- not be dirty after a load.
		if params.is_loading or RestoreState then
			ops.SetLevelName(params.is_loading)

			params.name = "load_level_wip"

			Runtime:dispatchEvent(params)

			params.name = nil

			events.ResolveLinks_Load(params)
			common.Undirty()
		end

		-- Install dialogs and trigger the default view.
		AddCommands(self.view, actions, funcs)
		AddNavigation(self.view)

		-- If the state was dirty before a test, then re-dirty it.
		if RestoreState and RestoreState.was_dirty then
			common.Dirty()
		end

		-- Remove evidence of any test and alert listeners that the WIP is opened.
		RestoreState = nil

		Runtime:dispatchEvent{ name = "level_wip_opened" }
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
	end
end

Scene:addEventListener("hide")

-- Finally, install the editor views.
EditorView = require_ex.DoList_Names(Names, Prefix)

return Scene