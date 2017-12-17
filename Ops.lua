--- Editor operations.

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
local ipairs = ipairs
local write = io.write

-- Modules --
local common = require("s3_editor.Common")
local events = require("s3_editor.Events")
local persistence = require("corona_utils.persistence")
local prompts = require("corona_ui.patterns.prompts")
local scenes = require("corona_utils.scenes")
local timers = require("corona_utils.timers")

-- Corona globals --
local native = native
local Runtime = Runtime
local system = system

-- Cached module references --
local _SetLevelName_
local _Verify_

-- Corona modules --
local composer = require("composer")

-- Is the level being saved or built temporary? --
local IsTemp

-- Working level name --
local LevelName

-- Editor scene view --
local View

-- Tries to get the level name; if successful, writes the level
local function GetLevelName (func, wip, follow_up)
	prompts.WriteEntry_MightExist(LevelName, {
		group = View, what = "level name",

		exists = function(name)
			return persistence.LevelExists(name, wip)
		end,

		writer = function(name)
			_SetLevelName_(name)

			local blob = persistence.Encode(func(), not wip)

			persistence.SaveLevel(name, blob, true, wip, IsTemp)

			if follow_up then
				follow_up()
			end
		end
	})
end

-- Common save / build logic
local function AuxSave ()
	local saved = { name = "save_level_wip", main = { common.GetDims() } }

	Runtime:dispatchEvent(saved)

	saved.name = nil

	events.ResolveLinks_Save(saved)

	return saved
end

--- Builds a game-ready version of the work-in-progress level, saving it in the database
-- under the working name. The level is first verified; if this fails, the build is aborted.
--
-- The build proceeds in two steps. First, the **save\_level\_wip** event is dispatched, with
-- a table event as per @{Save}. Second, the **build_level** event is dispatched with this
-- same table as event; listeners can then mutate the table into game-ready form.
--
-- This table is then added, as a string, to the level database.
-- @see s3_editor.Common.IsVerified, corona_utils.persistence.SaveLevel, GetLevelName, Verify
function M.Build ()
	_Verify_()

	if common.IsVerified() then
		GetLevelName(function()
			local level = AuxSave()

			level.name = "build_level"

			Runtime:dispatchEvent(level)

			level.name = nil

			events.ResolveLinks_Build(level)

			return level
		end, false)
	end
end

--- Cleans up various state used by editor operations.
function M.CleanUp ()
	IsTemp, LevelName, View = nil
end

--- Getter.
-- @treturn string|nil Current working name, if assigned.
-- @see SetLevelName
function M.GetLevelName ()
	return LevelName
end

--- Initializes various state used by editor operations.
-- @pgroup view Editor scene view.
-- @todo PARAMS
function M.Init (view)
	View = view
end

--- DOCME
function M.ListenForQuickTest (key_name, scene_name)
	scenes.SetListenFunc(function(what, key)
		if what == "message:handles_key" and key.keyName == key_name and key.phase == "down" and key.isCtrlDown then
			local exists, data = persistence.LevelExists("?TEST?")

			if exists then
				scenes.SetListenFunc(nil)
				scenes.GoToScene{ name = scene_name, params = data, effect = "none" }
			end
		end
	end)
end

--- Quits the editor.
function M.Quit ()
	composer.gotoScene("s3_editor.scene.Setup")
end

-- Save logic body
local function SaveBody (follow_up)
	if common.IsDirty() then
		GetLevelName(function()
			local scene = AuxSave()

			common.Undirty()

			return scene
		end, true, follow_up)
	end
end

--- Saves the work-in-progress level in the database under the working name.
--
-- If the editor state is not dirty, this is no-op.
--
-- A table of the form `to_save = { main = { _cols_, _rows_ } }` is prepared, where _cols_
-- and _rows_ are the tile-wise level dimensions. The **save\_level\_wip** event is dispatched
-- with this table as event; listeners can then fill it in.
--
-- This table is then added, as a string, to the level database (as a WIP).
-- @callable[opt] follow_up If present, called (without arguments) after saving.
-- @see s3_editor.Common.IsDirty, corona_utils.persistence.SaveLevel, GetLevelName
function M.Save ()
	SaveBody()
end

--- Variant of @{Save} that allows a follow-up action.
-- @function Save_FollowUp
-- @callable[opt] follow_up If present, called (without arguments) after saving.
M.Save_FollowUp = SaveBody

--- Sets the current working name, which is used by @{Build} and @{Save} to assign levels
-- into the database.
-- @tparam ?|string|nil name Name to assign, or **nil** to clear the working name.
-- @see corona_utils.persistence, GetLevelName
function M.SetLevelName (name)
	LevelName = name
end

--- Sets or clears an "is temporary" flag. Any level saved by @{Build} or @{Save} while this
-- flag is set will be ignored by @{corona_utils.persistence.GetLevels}.
-- @bool is_temp Is the level temporary, in the operations to follow?
function M.SetTemp (is_temp)
	IsTemp = not not is_temp
end

-- Safe instance retrieval
local function GetInstances (object)
	return common.GetInstances(object, "copy")
end

--- Verifies the game-ready integrity of the working version of the level.
--
-- If the editor state is already verified, this is a no-op.
--
-- One or more passes are run over the level data. On each pass, the **verify\_level\_wip**
-- event is dispatched, with a table as event. The table has the following fields:
--
-- * **get\_instances**: May be called as `instances = get_instances(object)`, where _object_
-- is the representative object, cf. @{s3_editor.Common.GetInstances} with **"copy"**.
-- * **get\_label**: May be called as `label = get_label(name)` to query any label, cf.
-- @{s3_editor.Common.GetLabel}.
-- * **links**: Links for the current editor session, cf. @{s3_editor.Common.GetLinks}.
-- * **pass**: Read-only **uint**. Starts at 1 and is incremented after each pass.
-- * **needs\_another\_pass**: **bool**. Begins each pass as **false**. To request another
-- pass, set it to true; a listener should never set it to false.
--
-- Errors may be appended to the array part of the table. They will be reported to the
-- user in an environment-specific way.
--
-- Verification runs until a pass ends either: with errors (failure) or without a request
-- for a follow-up pass (success). On success, the editor will be in the verified state.
-- @see s3_editor.Common.IsVerified
function M.Verify ()
	if not common.IsVerified() then
		local verify, done = { pass = 1, get_instances = GetInstances, get_label = common.GetLabel, links = common.GetLinks() }

		-- If the verification takes a while, post the activity indicator.
		timers.RepeatEx(function(event)
			if done then
				if event.count > 3 then
					native.setActivityIndicator(false)
				end

				return "cancel"

			elseif event.count == 3 then
				native.setActivityIndicator(true)
			end
		end, 10)

		-- Run all verification listeners (performing extra passes if requested), quitting
		-- if some issues came up.
		-- TODO: While not implemented yet, this is meant to be built with some form of yields
		-- in mind, either via coroutines or based on the timer
		verify.name = "verify_level_wip"

		repeat
			verify.needs_another_pass = false

			Runtime:dispatchEvent(verify)

			verify.pass = verify.pass + 1
		until #verify > 0 or not verify.needs_another_pass

		done, verify.name = true

		-- One or more issues: report in environment-appropriate way.
		if #verify > 0 then
			local message

			if system.getInfo("environment") == "device" then
				message = "First error: " .. verify[1]
			else
				message = "(See console)"

				write("Errors: ", "\n")

				for _, err in ipairs(verify) do
					write(err, "\n")
				end
			end

			native.showAlert("Scene has errors!", message)

		-- Verification successful.
		else
			common.Verify()
		end
	end
end

-- Cache module members.
_SetLevelName_ = M.SetLevelName
_Verify_ = M.Verify

-- Export the module.
return M