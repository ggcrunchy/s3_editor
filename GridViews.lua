--- Various useful, somewhat general grid view objects, and associated logic.

-- The following methods are available:
--
-- * **"grid"**: Boilerplate: editor grid function body.
-- * **"load"**: Boilerplate: editor view being loaded... (The assets directory prefix, viz.
-- in **"_prefix_\_Assets/", is passed through _col_, and a title for the current tile
-- @{corona_ui.widget.grid_1D} is passed through _row_.)
-- * **Enter(view)**: The editor view is being entered...
-- * **Exit**: ...exited...
-- * **Load(group, prefix, title)**: ...loaded...
-- * **Unload**: ...or unloaded.
-- * **GetCurrent**: Returns the current tile @{corona_ui.widgets.grid_1D}...
-- * **GetGrid**: ...@{corona_ui.widgets.grid}...
-- * **GetValues**: ...values table...
-- * **GetTiles**: ...or values and tiles tables.

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
local min = math.min
local type = type

-- Modules --
local common = require("s3_editor.Common")
local grid = require("s3_editor.Grid")
local grid1D = require("corona_ui.widgets.grid_1D")
local help = require("s3_editor.Help")
local sheet = require("corona_utils.sheet")
local strings = require("tektite_core.var.strings")
local tabs_patterns = require("corona_ui.patterns.tabs")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--- DOCME
-- @pgroup group
-- @array names
-- @callable func
-- @uint w
-- @treturn DisplayObject X
function M.AddTabs (group, names, func, w)
	local buttons = {}

	for i, label in ipairs(names) do
		buttons[i] = { label = label, onPress = func(label) }
	end

	local tabs = tabs_patterns.TabBar(group, buttons, { y = "from_bottom_align -.625%", left = "15%", width = w })

	tabs.isVisible = false

	tabs:setSelected(1, true)

	return tabs
end

--
local function CircleUpdate (canvas, tile, x, y, cw, ch)
	tile = tile or display.newCircle(canvas, 0, 0, min(cw, ch) / 2)

	tile:setStrokeColor(1, 0, 0)

	tile.strokeWidth, tile.x, tile.y = 3, x, y

	return tile
end

--- DOCME
function M.CircleUpdate (grid, x, y, tile)
	return CircleUpdate(grid:GetCanvas(), tile, x, y, grid:GetCellDims())
end

--
local function DefSame (tile)
	return tile
end

--
local function FrameSame (tile, which)
	return tile and tile.m_filename == which--sheet.GetSpriteSetImageFrame(tile) == which
end

-- --
local Fill = { type = "image" }

--
local function FrameUpdate (canvas, tile, x, y, cw, ch--[[, tile_images]], which)
	tile = tile or --[[sheet.NewImage(canvas, tile_images, x, y, ]]display.newRect(canvas, x, y, cw, ch)

	tile.fill, Fill.filename = Fill, which
--	sheet.SetSpriteSetImageFrame(tile, which)
	tile.m_filename = which

	return tile
end

--
local function ImageUpdate (canvas, tile, x, y, cw, ch, tile_images)
	tile = tile or display.newImageRect(canvas, tile_images, cw, ch)

	tile.x, tile.y = x, y

	return tile
end

--- DOCME
function M.ImageUpdate (grid, x, y, filename, tile)
	local w, h = grid:GetCellDims()

	return ImageUpdate(grid:GetCanvas(), tile, x, y, w, h, filename)
end

--- Common logic for the **PAINT** / **EDIT** / **ERASE** combination of grid operations.
-- @callable dialog_wrapper Cf. the result of @{s3_editor.Dialog.DialogWrapper}.
-- @tparam array|string types An array of strings denoting type.
-- @string[opt=""] palette 
-- @treturn GridView Editor grid view object.
function M.EditErase (dialog_wrapper, types, palette)
	local cells, choices, current, option, pick, tabs, tiles, try_option, tile_images, values

	--
	local same, update = DefSame

	if palette == "circle" then
		update = CircleUpdate
	elseif #(palette or "") ~= 0 then
		update, tile_images = ImageUpdate, palette
	else
		same, update = FrameSame, FrameUpdate
	end

	--
	local function Cell (event)
		local cur_choice = choices.m_cur
		local key, which = strings.PairToKey(event.col, event.row), cur_choice and cur_choice:GetSelection("filename")--current and current:GetCurrent()
		local cur, tile = values[key], tiles[key]
		local canvas, cw, ch = event.target:GetCanvas(), event.target:GetCellDims()

		--
		pick = grid.UpdatePick(canvas, pick, event.col, event.row, event.x, event.y, cw, ch)

		--
		if option == "Edit" then
			if cur then
				dialog_wrapper("edit", cur, --[[tabs]]choices.parent, key)
			else
				dialog_wrapper("close")
			end

		--
		elseif option == "Erase" then
			if tile then
				tile:removeSelf()

				common.BindRepAndValues(tile, nil)
				common.Dirty()
			end

			values[key], tiles[key] = nil

		--
		elseif not same(tile, which) then
			if tile then
				common.GetLinks():RemoveTag(tile)
			end

			local vtype = type(types) == "string" and types or cur_choice:GetSelection("text")--types[which]

			if vtype then
				values[key] = dialog_wrapper("new_values", vtype, key)
				tiles[key] = update(canvas, tile, event.x, event.y, cw, ch, which)--tile_images, which)

				--
				common.BindRepAndValuesWithTag(tiles[key], values[key], dialog_wrapper("get_tag", vtype), dialog_wrapper)
				common.Dirty()
			end
		end
	end

	--
	local function ShowHide (event)
		local key = strings.PairToKey(event.col, event.row)

		if values[key] then
			tiles[key].isVisible = event.show
		end

		grid.ShowPick(pick, event.col, event.row, event.show)
	end

	--
	local EditEraseGridView = {}

	--- DOCME
	function EditEraseGridView:Enter ()
		grid.Show(cells)
	--	try_option(tabs, option)
--[[
		if current then
			common.ShowCurrent(current, option == "Paint")
		end
]]
		choices.isVisible = true
--		tabs.isVisible = true
	end

	--- DOCME
	function EditEraseGridView:Exit ()
		dialog_wrapper("close")

		grid.SetChoice(option)
--[[
		if current then
			common.ShowCurrent(current, false)
		end
]]
		choices.isVisible = false
	--	tabs.isVisible = false

		grid.Show(false)
	end
--[[
	--- DOCME
	function EditEraseGridView:GetCurrent ()
		return current
	end

	-- ^^ RENAME, while about it? (e.g. choice)
]]
	--- DOCME
	function EditEraseGridView:GetChoices ()
		return choices
	end

	--- DOCME
	function EditEraseGridView:GetGrid ()
		return cells
	end

	--- DOCME
	function EditEraseGridView:GetTiles ()
		return tiles
	end

	--- DOCME
	function EditEraseGridView:GetValues ()
		return values
	end

	--- DOCME
	function EditEraseGridView:Load (group, prefix)
		values, tiles, cells = {}, {}, grid.NewGrid()

		cells:addEventListener("cell", Cell)
		cells:addEventListener("show", ShowHide)

		--
		local options = { "Paint", "Edit", "Erase" }
		local commands = {
			title = prefix .. " commands",

			"Mode:", { column = options, column_width = 60 }, "m_mode",
		}

		if update == FrameUpdate then
		--	current = grid1D.OptionsHGrid(group, "18.75%", "10.4%", "25%", "20.8%", title, { types = types })
			local column, editor_event = {}, dialog_wrapper("get_editor_event")

			for _, name in ipairs(types) do
				column[#column + 1] = { filename = editor_event(name, "get_thumb_filename"), text = name }
			end

			commands[#commands + 1] = prefix .. ":"
			commands[#commands + 1] = { column = column }
			commands[#commands + 1] = "m_cur"
		end

		choices, option = common.AddCommandsBar(commands), "Paint"
		choices.isVisible = false

		choices.m_mode:addEventListener("item_change", function(event)
			local label = event.text

			if label ~= "Edit" then
				dialog_wrapper("close")
			end

			option = label
		end)
		group:insert(choices)

		--
--[[
		tabs = M.AddTabs(group, options, function(label)
			return function()
				option = label

				if current then
					common.ShowCurrent(current, label == "Paint")
				end

				if label ~= "Edit" then
					dialog_wrapper("close")
				end

				return true
			end
		end, "37.5%")
]]
		--
		try_option = grid.ChoiceTrier(options)
--[[
		--
		if current then
			tile_images = common.SpriteSetFromThumbs(dialog_wrapper("get_editor_event"), types)

			current:Bind(tile_images, #tile_images)
			current:toFront()

			common.ShowCurrent(current, false)
		end
]]
		--
	--	help.AddHelp(prefix, { current = current, tabs = tabs })
	end

	--- DOCME
	function EditEraseGridView:Unload ()
	--	tabs:removeSelf()

		cells, current, option, pick, tabs, tiles, tile_images, try_option, values = nil
	end

	return EditEraseGridView
end

-- Export the module.
return M