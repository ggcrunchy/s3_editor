--- Some operations, e.g. for persistence and verification, reused among editor events.
--
-- Many operations take an argument of type **View**. For an example of such an object (or
-- rather, the derived **GridView**), see @{s3_editor.GridViews.EditErase}.

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
local common = require("s3_editor.Common")
local grid = require("s3_editor.Grid")
local strings = require("tektite_core.var.strings")
local table_funcs = require("tektite_core.table.funcs")

-- Cached module references --
local _CheckForNameDups_
local _LoadValuesFromEntry_
local _SaveValuesIntoEntry_

-- Exports --
local M = {}

--
--
--

--- Helper to build a level-ready entry.
-- TODO: needs some work, at very least something about instances and timing of name
-- @ptable level Built level state. (Basically, this begins as saved level state, and
-- is restructured into build-appropriate form.)
--
-- If _from_ indicates a link, some intermediate state is stored in the **links** table (this
-- being a build, the state is assumed to be well-formed, i.e. this table exists).
-- @{ResolveLinks_Build} should be called once all build operations are complete, to turn
-- this state into application-ready form.
--
-- Specifically, if a "prep link" handler exists, it will be stored (with the built entry
-- as key) for lookup during resolution.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of value being built.
--
-- A **"prep_link"** editor event takes as arguments, in order: _level_, _built_, where
-- _built_ is the copy of _entry_, minus the **name** and **uid** fields. If it returns a
-- handler function, that will be called during resolution, cf. @{ResolveLinks_Build}.
--
-- A **"build"** editor event takes as arguments, in order: _level_, _entry_, _built_. Any
-- final changes to _built_ may be performed here.
-- @ptable entry Entry to build. The built entry itself will be a copy of this, with **name**
-- and **uid** stripped, plus any changes performed in the **"build"** logic; _entry_ itself
-- is left intact in case said logic still has need of those members.
-- @array? acc Accumulator table, to which the built entry will be appended. If absent, a
-- table is created.
-- @treturn array _acc_.
function M.BuildEntry (level, mod, entry, acc)
	acc = acc or {}

	local built, instances = table_funcs.Copy(entry), entry.instances

	if instances then
		built.instances = nil

		mod.EditorEvent(entry.type, "build_instances", built, {
			instances = instances, labels = level.labels, links = common.GetLinks()
		})
	end

	built.positions = nil

	if entry.uid then
		level.links[entry.uid], built.uid = built

		local prep_link, cleanup = mod.EditorEvent(entry.type, "prep_link", level, built)

		level.links[built] = prep_link

		if cleanup then
			level.cleanup = level.cleanup or {}
			level.cleanup[built] = cleanup
		end
	end

	built.name = nil

	mod.EditorEvent(entry.type, "build", level, entry, built)

	acc[#acc + 1] = built

	return acc
end

--- Helper to detect if a name has been added yet to a set of names. If not, it is added
-- (with the name as key) along with _values_'s type (for later errors, if necessary);
-- otherwise, an error message is appended to the verify block.
-- @string what What type of value is being named (for error messages)?
-- @array verify Verify block.
-- @ptable names Names against which to validate.
-- @ptable values Candidate values to add, if its **name** field is unique.
-- @treturn boolean Was _values_ a duplicate?
function M.CheckForNameDups (what, verify, names, values)
	local type = names[values.name]

	if not type then
		names[values.name] = values.type
	else
		verify[#verify + 1] = ("Duplicated %s name: `%s` of type `%s`; already used by %s of type `%s`"):format(what, values.name, values.type, what, type)
	end

	return type ~= nil
end

--- Helper to detect if there are duplicate names among a group of values.
--
-- Essentially, this creates a temporary _names_ table and then performs @{CheckForNameDups}
-- on each blob of values in the group.
-- @string what What type of value is being named (for error messages)?
-- @array verify Verify block.
-- @tparam View view Supplies the module's values.
-- @treturn boolean Were there any duplicates?
function M.CheckNamesInValues (what, verify, view)
	local names, values = {}, view:GetValues()

	for _, v in pairs(values) do
		if _CheckForNameDups_(what, verify, names, v) then
			return true
		end
	end

	return false
end

--- Helper to load a group of value blobs, which values are assumed to be grid-bound in the
-- editor. Some concomitant work is performed in order to produce a consistent grid.
-- @ptable level Loaded level state, as per @{LoadValuesFromEntry}.
-- @string what The group to load is found under `level[what].entries`.
-- @ptable mod Module, as per @{LoadValuesFromEntry}.
--
-- In addition, if _mod_ contains a **GetTypes** function, which in turn returns an array of
-- type names, the current tile grid (if available) will be indexed to a given entry's type
-- before that entry's cell is loaded.
-- @tparam GridView grid_view Supplies the module's current tile grid, values, and tiles.
--
-- If _grid\_view_ does not contain a **GetChoices method, or if it returns **nil**, the
-- current menu is considered unavailable and ignored during loading.
function M.LoadGroupOfValues_Grid (level, what, mod, grid_view)
	local cells = grid_view:GetGrid()

	grid.Show(cells)

	level[what].version = nil

	local values, tiles = grid_view:GetValues(), grid_view:GetTiles()
	local gcfunc = grid_view.GetChoices
	local current = gcfunc and gcfunc(grid_view)

	current = current and current.m_cur

	for k, entry in pairs(level[what].entries) do
		if current then
			current:Select(entry.type)
		end

		cells:TouchCell(strings.KeyToPair(k))

		_LoadValuesFromEntry_(level, mod, values[k], entry)
	end

	if current then
		current:Select(nil, "first_in_first_column")
	end

	grid.ShowOrHide(tiles)
	grid.Show(false)
end

--- DOCME
function M.LoadGroupOfValues_List (level, what, mod, list_view)
	level[what].version = nil

	local n, list, values = 0, list_view:GetListbox(), list_view:GetValues()

	for k, entry in pairs(level[what].entries) do
		-- Add and populate a new entry.
		values[k], n = list_view:AddEntry(k, entry.type), n + 1

		_LoadValuesFromEntry_(level, mod, values[k], entry)

		-- Account for name changes.
		list:Update(n)
	end
end

-- Default values for the type being saved or loaded --
-- TODO: How much work would it be to install some prefab logic?
local Defs

-- Assign reasonable defaults to missing keys
local function AssignDefs (item)
	for k, v in pairs(Defs) do
		if item[k] == nil then
			item[k] = v
		end
	end
end

-- Current module and value type being saved or loaded --
local Mod, ValueType

-- Enumerate defaults for a module / element type combination, with caching
local function EnumDefs (mod, value)
	if Mod ~= mod or ValueType ~= value.type then
		Mod, ValueType = mod, value.type

		Defs = { name = "", type = ValueType }

		mod.EditorEvent(ValueType, "enum_defs", Defs)
	end
end

--

--- Helper to load a blob of values.
-- @ptable level Loaded level state. (Basically, this begins as saved level state, and
-- is restructured into load-appropriate form.)
--
-- If _entry_ indicates a link, some intermediate state is stored in the **links** table
-- (this being a load, the state is assumed to be well-formed, i.e. this table exists).
-- @{ResolveLinks_Load} should be called once all load operations are complete, to turn
-- this state into editor-ready form.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of value being loaded.
--
-- A **"load"** editor event takes as arguments, in order: _level_, _entry_, _values_. Any
-- final changes to _values_ may be performed here.
-- @ptable values Blob of values to populate.
-- @ptable entry Editor state entry which will provide the values to load.
function M.LoadValuesFromEntry (level, mod, values, entry)
	EnumDefs(mod, entry)

	-- If the entry will be involved in links, stash its rep so that it gets picked up (as
	-- "entry") by ReadLinks() during resolution.
	local rep = common.GetRepFromValues(values)

	if entry.uid then
		level.links[entry.uid] = rep
	end

	--
	local links, labels, resolved = common.GetLinks()
	local tag_db, tag = links:GetTagDatabase(), links:GetTag(rep)

	for i = 1, #(entry.instances or "") do
		local name = entry.instances[i]

		labels, resolved = labels or level.labels, resolved or {}
		resolved[name] = tag_db:ReplaceSingleInstance(tag, name)

		common.AddInstance(rep, resolved[name])
		common.SetLabel(resolved[name], labels and labels[name])
	end

	-- Restore any positions.
	common.SetPositions(rep, entry.positions)

	entry.positions = nil

	-- Copy the editor state into the values, alert any listeners, and add defaults as necessary.
	entry.instances = nil

	for k, v in pairs(entry) do
		values[k] = v
	end

	mod.EditorEvent(ValueType, "load", level, entry, values)

	AssignDefs(values)
end

-- Reads (resolved) "saved" links, processing them into "built" or "loaded" form
local function ReadLinks (level, on_entry, on_pair)
	local list, index, entry, sub = level.links, 1

	for i = 1, #list, 2 do
		local item, other = list[i], list[i + 1]

		-- Entry pair: Load the entry via its ID (note that the build and load pre-resolve steps
		-- both involve stuffing the ID into the links) and append it to the entries array. If
		-- there is a per-entry visitor, call it along with its entry index.
		if item == "entry" then
			entry = list[other]

			on_entry(entry, index)

			list[index], index = entry, index + 1

		-- Sublink pair: Get the sublink name.
		elseif item == "sub" then
			sub = other

		-- Other object sublink pair: The saved entry stream is a fat representation, with both
		-- directions represented for each link, i.e. each sublink pair will be encountered twice.
		-- The first time, only "entry" will have been loaded, and should be ignored. On the next
		-- pass, pair the two entries, since both will be loaded.
		elseif index > item then
			on_pair(list, entry, list[item], sub, other)
		end
	end
end

--- Resolves any link information produced by @{BuildEntry}.
--
-- In each linked pair, one or both entries may have provided a "prep link" handler. If so,
-- the available handlers are called as
--    handler(entry1, entry2, sub1, sub2)
-- where _entry1_ and _sub1_ are the entry and sublink associated with the handler; _entry2_
-- and _sub2_ make up the target. At this point, all entries will have their final **uid**'s,
-- so this is the ideal time to bind everything as the application expects, e.g. via @{tektite_core.bind}.
--
-- Once finished, the editor state is storage-ready.
-- @ptable level Saved level state. If present, the **links** table is read and processed;
-- any link information is moved into the entries, and **links** is removed.
function M.ResolveLinks_Build (level)
	if level.links then
		ReadLinks(level, function(entry, index)
			entry.uid = index
		end, function(list, entry1, entry2, sub1, sub2)
			local func1, func2 = list[entry1], list[entry2]

			if func1 then
				func1(entry1, entry2, sub1, sub2)
			end

			if func2 then
				func2(entry2, entry1, sub2, sub1)
			end
		end)

		-- Tidy up any information only needed during linking.
		if level.cleanup then
			for entry, cleanup in pairs(level.cleanup) do
				cleanup(entry)
			end

			level.cleanup = nil
		end

		-- All labels and link information have now been incorporated into the entries
		-- themselves, so there is no longer need to retain it in the editor state.
		level.labels, level.links = nil
	end
end

-- Helper to resolve sublinks that might be instantiated templates; since this is a new session, we need to
-- request new names for each instance to maintain consistency
local function ResolveSublink (name, resolved)
	return resolved and resolved[name] or name
end

--- Resolves any link information produced by @{LoadGroupOfValues_Grid} and @{LoadValuesFromEntry}.
--
-- Once finished, the loaded values are ready to be edited.
--
-- **N.B.** Loading might change some IDs. In particular, templated sublink instances are subject to
-- renaming to maintain consistency with the tag database's state.
-- @ptable level Saved level state. If present, the **links** table is read, and links are
-- established between editor-side values.
function M.ResolveLinks_Load (level)
	if level.links then
		local links, resolved = common.GetLinks(), level.resolved

		ReadLinks(level, function() end, function(_, obj1, obj2, sub1, sub2)
			sub1 = ResolveSublink(sub1, resolved)
			sub2 = ResolveSublink(sub2, resolved)

			links:LinkObjects(obj1, obj2, sub1, sub2)
		end)
	end
end

--
local function GatherLabel (name, labels)
	local label = common.GetLabel(name)

	if label then
		labels = labels or {}
		labels[name] = label
	end

	return labels
end

--- Resolves any link information produced by @{SaveGroupOfValues} and @{SaveValuesIntoEntry}.
--
-- Once finished, the editor state is storage-ready.
--
-- The editor state is placed into a form ready to be consumed by build or load operations.
-- @ptable level Saved level state. If present, the **links** table is read, processed, and
-- finally replaced by a "resolved" form.
--
-- The "resolved" form is a stream of pairs:
--
-- "entry" (literal), entry's ID (string)
--    "sub" (literal), entry's sublink name (string)
--      array index of other entry (integer), other entry's sublink name (string)
--
-- The stream is composed of one or more **"entry"** pairs (an entry), each composed in turn
-- of one or more **"sub"** pairs (its sublinks), each of those in turn made up of lookup
-- information (the sublink's targets).
--
-- This is a fat representation, where link information is stored in both directions.
function M.ResolveLinks_Save (level)
	local list = level.links

	if list then
		local new, links, labels = {}, common.GetLinks()
		local tag_db = links:GetTagDatabase()

		for _, rep in ipairs(list) do
			local entry = common.GetValuesFromRep(rep)

			new[#new + 1] = "entry"
			new[#new + 1] = entry.uid

			entry.uid = nil

			for _, sub in tag_db:Sublinks(links:GetTag(rep), "no_templates") do
				new[#new + 1] = "sub"
				new[#new + 1] = sub

				labels = GatherLabel(sub, labels)

				for link in links:Links(rep, sub) do
					local obj, osub = link:GetOtherObject(rep)

					new[#new + 1] = list[obj]
					new[#new + 1] = osub

					labels = GatherLabel(sub, labels)
				end
			end
		end

		level.links, level.labels = new, labels
	end
end

--- Helper to save a group of value blobs.
-- @ptable level Saved level state, as per @{SaveValuesIntoEntry}.
-- @string what The group to load is found under `level[what].entries`.
-- @ptable mod Module, as per @{SaveValuesIntoEntry}.
-- @tparam View view Supplies the module's values.
function M.SaveGroupOfValues (level, what, mod, view)
	local target = {}

	level[what] = { entries = target, version = 1 }

	local values = view:GetValues()

	for k, v in pairs(values) do
		target[k] = _SaveValuesIntoEntry_(level, mod, v, {})
	end
end

-- Is the (represented) object linked to anything?
local function HasAny (rep)
	local links = common.GetLinks()
	local tag = links:GetTag(rep)

	if tag then
		local f, s, v0, reclaim = links:GetTagDatabase():Sublinks(tag, "no_templates")

		for _, sub in f, s, v0 do
			if links:HasLinks(rep, sub) then
				reclaim()

				return true
			end
		end
	end
end

--- Helper to save a blob of values.
--
-- **N.B.** This may intrusively modify _values_ (namely, adding a **uid** field to it).
-- @{ResolveLinks_Save} will clean up after these modifications.
-- @ptable level Saved level state. If _values_ has links, some intermediate state is stored
-- in the **links** table (which is created, if necessary). @{ResolveLinks_Save} should be
-- called once all save operations are complete, to turn this state into save-ready form.
--
-- Specifically, _values_'s representative object is appended to an array, to be iterated;
-- its array position is also stored for quick lookup, with the object as key.
--
-- At this stage, the **uid** is set to some unique (within the current batch of saves) string,
-- mainly for easy visual comparison.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of value being saved.
--
-- A **"save"** editor event takes as arguments, in order: _level_, _entry_, _values_. Any
-- final changes to _entry_ may be performed here.
-- @ptable values Blob of values to save.
-- @ptable entry Editor state entry which will receive the saved values.
-- @treturn ptable _entry_.
function M.SaveValuesIntoEntry (level, mod, values, entry)
	EnumDefs(mod, values)

	-- Does this values blob have any links? If so, make note of it in the blob itself and
	-- add some tracking information in the links list.
	local rep = common.GetRepFromValues(values)

	if HasAny(rep) then
		local list = level.links or {}

		if not list[rep] then
			values.uid = strings.NewName()

			list[#list + 1] = rep
			list[rep] = #list
		end

		level.links = list
	end

	-- Copy the values into the editor state, alert any listeners, and add defaults as necessary.
	for k, v in pairs(values) do
		entry[k] = v
	end

	mod.EditorEvent(ValueType, "save", level, entry, values)

	AssignDefs(entry)

	entry.positions, entry.instances = common.GetPositions(rep), common.GetInstances(rep, "copy")

	return entry
end

--- Verify all values (i.e. blobs of editor-side object data) in a given module.
-- @ptable verify Verify block.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of values being verified.
--
-- A **"verify"** editor event takes as arguments, in order: _verify_, _ovals_, _rep_, where
-- _ovals_ is a table of object values to verify, and _rep_ is the object's representative.
-- @tparam View view Supplies the module's values.
function M.VerifyValues (verify, mod, view)
	local values = view:GetValues()

	for _, v in pairs(values) do
		mod.EditorEvent(v.type, "verify", verify, v, common.GetRepFromValues(v))
	end
end

_CheckForNameDups_ = M.CheckForNameDups
_LoadValuesFromEntry_ = M.LoadValuesFromEntry
_SaveValuesIntoEntry_ = M.SaveValuesIntoEntry

return M