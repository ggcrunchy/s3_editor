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
local layout = require("corona_ui.utils.layout")
local menu = require("corona_ui.widgets.menu")
local sheet = require("corona_utils.sheet")
local strings = require("tektite_core.var.strings")
local tabs_patterns = require("corona_ui.patterns.tabs")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- --
local DragTouch = touch.DragParentTouch{ ref_key = "m_back" }

-- --
local BackHeight, BarHeight = 30, 16

--- DOCME
function M.AddCommandsBar (params)
	local cgroup, h, prev = display.newGroup(), BackHeight + BarHeight
	local back = display.newRect(cgroup, 0, .5 * h, 1, h)
	local bar, y = display.newRect(cgroup, 0, .5 * BarHeight, 1, BarHeight), h - .5 * BackHeight

	bar:addEventListener("touch", DragTouch)
	bar:setFillColor(0, 0, 1)
	bar:setStrokeColor(0, 0, .6)
	back:setFillColor(.7)
	back:setStrokeColor(.6, .7)

	back.anchorX, back.x = 0, 0
	bar.anchorX, bar.x = 0, 0
	back.strokeWidth, bar.strokeWidth = 2, 1

	bar.m_back = back

	for i = 1, #params, 3 do
		local str, dparams = display.newText(cgroup, params[i], 0, y, native.systemFont, 16), params[i + 1]

		dparams.group, dparams.heading_height, dparams.size = cgroup, BackHeight - 8, 12

		local dropdown = menu.Dropdown(dparams)

		layout.PutRightOf(str, prev, 5)
		layout.PutRightOf(dropdown, str, 5)

		local stash = dropdown:StashDropdowns()

		layout.CenterAtY(dropdown, y)

		dropdown:RestoreDropdowns(stash)

		cgroup[params[i + 2]], prev = dropdown, dropdown
	end

	local w = layout.RightOf(prev, 5)

	back.path.width, bar.path.width = w, w

	layout.CenterAtX(cgroup, "50%")
	layout.TopAlignWith(cgroup, "87.5%")

	touch.Spoof(cgroup)

	return cgroup
end

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
local function FrameSame (tile, which, cur) -- TODO: can 'tile' sub for 'cur' ?(then we have a pattern...)
	return cur and sheet.GetSpriteSetImageFrame(tile) == which
end

--
local function FrameUpdate (canvas, tile, x, y, cw, ch, tile_images, which)
	tile = tile or sheet.NewImage(canvas, tile_images, x, y, cw, ch)

	sheet.SetSpriteSetImageFrame(tile, which)

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
	local cells, current, option, pick, tabs, tiles, try_option, tile_images, values

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
		local key, which = strings.PairToKey(event.col, event.row), current and current:GetCurrent()
		local cur, tile = values[key], tiles[key]
		local canvas, cw, ch = event.target:GetCanvas(), event.target:GetCellDims()

		--
		pick = grid.UpdatePick(canvas, pick, event.col, event.row, event.x, event.y, cw, ch)

		--
		if option == "Edit" then
			if cur then
				dialog_wrapper("edit", cur, tabs.parent, key)
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
		elseif not same(tile, which, cur) then
			if tile then
				common.GetLinks():RemoveTag(tile)
			end

			local vtype = type(types) == "string" and types or types[which]

			if vtype then
				values[key] = dialog_wrapper("new_values", vtype, key)
				tiles[key] = update(canvas, tile, event.x, event.y, cw, ch, tile_images, which)

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
		try_option(tabs, option)

		if current then
			common.ShowCurrent(current, option == "Paint")
		end

		tabs.isVisible = true
	end

	--- DOCME
	function EditEraseGridView:Exit ()
		dialog_wrapper("close")

		grid.SetChoice(option)

		if current then
			common.ShowCurrent(current, false)
		end

		tabs.isVisible = false

		grid.Show(false)
	end

	--- DOCME
	function EditEraseGridView:GetCurrent ()
		return current
	end

	-- ^^ RENAME, while about it? (e.g. choice)

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
	function EditEraseGridView:Load (group, prefix, title)
		values, tiles, cells = {}, {}, grid.NewGrid()

		cells:addEventListener("cell", Cell)
		cells:addEventListener("show", ShowHide)

		--
		if update == FrameUpdate then
			current = grid1D.OptionsHGrid(group, "18.75%", "10.4%", "25%", "20.8%", title, { types = types })
		end

		--
		local choices = { "Paint", "Edit", "Erase" }

		tabs = M.AddTabs(group, choices, function(label)
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

		--
		try_option = grid.ChoiceTrier(choices)

		--
		if current then
			tile_images = common.SpriteSetFromThumbs(dialog_wrapper("get_editor_event"), types)

			current:Bind(tile_images, #tile_images)
			current:toFront()

			common.ShowCurrent(current, false)
		end

		--
		help.AddHelp(prefix, { current = current, tabs = tabs })
	end

	--- DOCME
	function EditEraseGridView:Unload ()
		tabs:removeSelf()

		cells, current, option, pick, tabs, tiles, tile_images, try_option, values = nil
	end

	return EditEraseGridView
end

-- Export the module.
return M