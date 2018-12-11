--- Various pieces that make up a link environment.

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
local next = next
local pairs = pairs
local setmetatable = setmetatable

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local link_collection = require("s3_editor.LinkCollection")
local object_vars = require("config.ObjectVariables")

-- Exports --
local M = {}

--
--
--

local Linker = {}

Linker.__index = Linker

--- DOCME
function Linker:AddGeneratedName (id, gend)
	local into = self.m_generated or {}
	local glist = into[id] or {}

	self.m_generated, into[id], glist[#glist + 1] = into, glist, gend
end

--
function M.AttachLinkInfo (object, info)
	local old_info = object.m_link_info

	object.m_link_info = info

	return old_info
end

--
local function BackBind (L, values, id)
	if values ~= nil then
		L.m_values_to_id[values] = id
	end
end

--- DOCME
function Linker:BindIdentifierAndValues (id, values)
	local prev_values

	if id then
		prev_values = self.m_id_to_values[id]

		BackBind(self, prev_values, nil)
		BackBind(self, values, id)

		self.m_id_to_values[id] = values
	end

	return prev_values
end

-- --
local LinkInfo -- TODO!

--- DOCME
-- TODO: actually bind type (or just do when making values, really...)
function Linker:BindIdentifierAndValuesWithTag (id, values, tag, dialog)
	if tag then
		self:BindIdentifierAndValues(id, values)
-- TODO!
		self.m_links:SetTag(id, tag)
-- /TODO
		if dialog then
			LinkInfo = LinkInfo or {}
-- TODO!
			dialog("get_link_info", values.type, LinkInfo, id)
-- /TODO!
			if next(LinkInfo, nil) then
				self:AttachLinkInfo(id, LinkInfo)

				LinkInfo = nil
			end
		end
	end
end

-- --
local LinkGroupings

--- DOCME
function Linker:GetGeneratedNames (id, how)
	local from = self.m_generated
	local glist = from and from[id]

	if how == "copy" and glist then
		local into = {}

		for _, gend in ipairs(glist) do
			into[#into + 1] = gend
		end

		return into
	end

	return glist
end

--- DOCME
function Linker:GetPositions (id)
	local from = self.m_positions

	return from and from[id]
end

--- Getter.
-- @string name Name to label, e.g. an instanced sublink.
-- @treturn ?|string|nil Current label, or **nil** if none is assigned.
function Linker:GetLabel (name)
	local from = self.m_labels

	return from and from[name]
end

--- DOCME
function M.GetLinkGrouping (tname)
	return LinkGroupings and LinkGroupings[tname] -- TODO!
end

--- DOCME
function Linker:GetLinkCollection ()
	return self.m_link_collection
end

--- DOCME
-- @ptable values
-- @treturn ID id
function Linker:GetIdentifierFromValues (values)
	return self.m_values_to_id[values]
end
--[[
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
]]
--- DOCME
-- @tparam ID id
-- @treturn table T
function Linker:GetValuesFromIdentifier (id)
	return self.m_id_to_values[id]
end

--- DOCME
function Linker:RemoveGeneratedName (id, gend)
	local generated = self.m_generated
	local glist = generated and generated[id]

	if gend ~= "all" then
		local n = #glist

		for i = 1, n do
			if glist[i] == gend then
				self:SetLabel(gend, nil)

				glist[i] = glist[n]
				glist[n] = nil

				break
			end
		end
	elseif glist then
		for _, gend in ipairs(glist) do
			self:SetLabel(gend, nil)
		end

		generated[id] = nil
	end
end

--- Attach a label to a name, e.g. to attach user-defined information.
-- @string name Name to label.
-- @tparam ?|string|nil Label to assign, or **nil** to remove the label.
function Linker:SetLabel (name, label)
	local into = self.m_labels

	if label then
		into = into or {}
		self.m_labels, into[name] = into, label
	elseif into then
		into[name] = nil
	end
end

--- DOCME
function Linker:SetPositions (id, positions)
	local into = self.m_positions

	if into or positions then -- possible to assign or clear?
		into = into or {}
		self.m_positions, into[id] = into, positions
	end
end

--- DOCME
function M.New ()
	local linker = {
		m_id_to_values = {}, m_values_to_id = {},
		m_link_collection = link_collection.New()
	}

	return setmetatable(linker, Linker)
end

return M