--- Class used to maintain a set of links between objects.
--
-- Linkages are formed between (**ID**, **Name**) pairs, comprising an identifier (such as a
-- unique integer) for a given object, along with the name of the endpoint to link.
-- An object may be linked to multiple objects, or even multiple times to the same
-- object via different endpoints.
--
-- The **ID** type is user-defined, but may be anything other than **nil** or NaN. Some
-- operations use @{tostring} for ordering purposes, so care should be taken to
-- avoid clashes. Any value may be used as a **Name**.
-- @module LinkCollection

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
local assert = assert
local ipairs = ipairs
local next = next
local pairs = pairs
local rawequal = rawequal
local setmetatable = setmetatable
local tostring = tostring

-- Cookies --
local _nan = {}

-- Exports --
local M = {}

--
--
--

local Link = {}

Link.__index = Link

local function LinkPosition (owner, link)
	local n = #owner

	for i = 1, n do
		if owner[i] == link then
			return i, n
		end
	end
end

--- If this link is intact, break it.
-- @see Link:IsIntact
function Link:Break ()
	local pair_links = self.m_owner

	if pair_links then
		local i, n = LinkPosition(pair_links, self)

		assert(i, "Link not found in list")

		pair_links[i] = pair_links[n]
		pair_links[n] = nil

		self.m_owner = nil -- n.b. list might now be empty but keep around
	end
end

local function SanitizeName (name)
	return rawequal(name, _nan) and 0 / 0 or name
end

---
-- @treturn[1] ID ID #1...
-- @treturn[1] Name ...and name of corresponding endpoint.
-- @treturn[1] ID ID #2...
-- @treturn[1] Name ...ditto.
-- @return[2] **nil**, meaning the link is no longer intact.
-- @see Link:GetOtherPair, Link:IsIntact
function Link:GetLinkedPairs ()
	local pair_links = self.m_owner

	if pair_links then
		return pair_links.m_id1, SanitizeName(self.m_name1), pair_links.m_id2, SanitizeName(self.m_name2)
	end

	return nil
end

---
-- @tparam ID id
-- @treturn[1] ID The ID paired with _id_ in this link...
-- @treturn[1] Name ...and its endpoint name.
-- @return[2] **nil**, meaning neither pair uses _id_ or the link is no longer intact.
-- @see LinkCollection:LinkPairs, Link:GetLinkedPairs, Link:IsIntact
function Link:GetOtherPair (id)
	local pair_links = self.m_owner

	if pair_links then
		local id1, id2 = pair_links.id1, pair_links.id2

		if rawequal(id, id1) then
			return id2, SanitizeName(self.m_name2)
		elseif rawequal(id, id2) then
			return id1, SanitizeName(self.m_name1)
		end
	end

	return nil
end

---
-- @treturn boolean The link is still intact?
-- @see LinkCollection:LinkPairs, LinkCollection:Remove, Link:Break
function Link:IsIntact ()
	return self.m_owner ~= nil
end

local LinkCollection = {}

LinkCollection.__index = LinkCollection

local function NameKey (sid1, id2)
	return sid1 < tostring(id2) and "m_name1" or "m_name2"
end

---
-- @tparam ID id
-- @tparam Name name
-- @treturn uint Number of links to _id_ via _name_.
function LinkCollection:CountLinks (id, name)
	local list, count = self[id], 0

	if list then
		local sid1 = tostring(id)

		for id2, pair_links in pairs(list) do
			local key = NameKey(sid1, id2)

			for _, link in ipairs(pair_links) do
				if rawequal(link[key], name) then
					count = count + 1
				end
			end
		end
	end

	return count
end

--- DOCME
-- @tparam ID id
-- @tparam Name name
-- @callable func
-- @param arg
function LinkCollection:ForEachPairLink (id, name, func, arg)
	local list = self[id]

	if list then
		local sid = tostring(id)

		for id2, pair_links in pairs(list) do
			local key = NameKey(sid, id2)

			for _, link in ipairs(pair_links) do
				if rawequal(link[key], name) then
					func(link, id, arg)
				end
			end
		end
	end
end

--- DOCME
-- @callable func
-- @param arg
function LinkCollection:ForEachLink (func, arg)
	for id1, list in pairs(self) do
		local sid1 = tostring(id1)

		for id2, pair_links in pairs(list) do
			if sid1 < tostring(id2) then -- first time seeing pair?
				for _, link in ipairs(pair_links) do
					func(link, arg)
				end
			end
		end
	end
end

--- DOCME
-- @tparam ID id
-- @callable func
-- @param arg
function LinkCollection:ForEachLinkWithID (id, func, arg)
	local list = self[id]

	if list then
		for _, pair_links in pairs(list) do
			for _, link in ipairs(pair_links) do
				func(link, id, arg)
			end
		end
	end
end

---
-- @tparam ID id
-- @tparam Name name
-- @treturn boolean X
function LinkCollection:HasLinks (id, name)
	local list = self[id]

	if list then
		local sid = tostring(id)

		for id2, pair_links in pairs(list) do
			local key = NameKey(sid, id2)

			for _, link in ipairs(pair_links) do
				if rawequal(link[key], name) then
					return true
				end
			end
		end
	end

	return false
end

local function AuxIterIDs (LC, prev)
	return (next(LC, prev))
end

---
-- @return Iterator that supplies each **ID** involved in links.
-- @see LinkCollection:LinkPairs, LinkCollection:Remove
function LinkCollection:IterIDs ()
	return AuxIterIDs, self, nil
end

local function FindLink (pair_links, name1, name2)
	for _, link in ipairs(pair_links) do
		if rawequal(link.m_name1, name1) and rawequal(link.m_name2, name2) then
			return link
		end
	end
end

local function GetList (LC, id)
	local list = LC[id] or {}

	LC[id] = list

	return list
end

--- DOCME
-- @tparam ID id1
-- @tparam Name name1
-- @tparam ID id2
-- @tparam Name name2
-- @treturn[1] Link L
-- @return[2] **nil**, indicating failure.
-- @treturn[2] string Reason for failure.
function LinkCollection:LinkPairs (id1, name1, id2, name2)
	assert(id1 ~= nil and id1 == id1, "Invalid ID #1")
	assert(id2 ~= nil and id2 == id2, "Invalid ID #2")

	if name1 ~= name1 then
		name1 = _nan
	end

	if name2 ~= name2 then
		name2 = _nan
	end

	local sid1, sid2 = tostring(id1), tostring(id2)

	if sid1 == sid2 then
		return nil, (rawequal(id1, id2) and "Equal" or "Ambiguous") .. " IDs"
	elseif sid2 < sid1 then -- impose an arbitrary but consistent order for later lookup
		id1, id2, name1, name2 = id2, id1, name2, name1
	end

	local list1, list2 = GetList(self, id1), GetList(self, id2)
	local pair_links = list1[id2]

	assert(pair_links == list2[id1], "Mismatched pair links") -- same table or both nil

	if pair_links then
		assert(tostring(pair_links.id1) == sid1, "Mismatch with pair ID #1")
		assert(tostring(pair_links.id2) == sid2, "Mismatch with pair ID #2")

		if FindLink(pair_links, name1, name2) then
			return nil, "IDs already linked via these endpoints"
		end
	else
		pair_links = { id1 = id1, id2 = id2 }
		list1[id2], list2[id1] = pair_links, pair_links
	end

	local link = setmetatable({ m_owner = pair_links, m_name1 = name1, m_name2 = name2 }, Link)

	pair_links[#pair_links + 1] = link

	return link
end

--- DOCME
-- @tparam ID id
-- @see Link:IsIntact
function LinkCollection:Remove (id)
	local list = self[id]

	if list then
		for id2, pair_links in pairs(list) do
			for _, link in ipairs(pair_links) do
				link.m_owner = nil -- links might still be referenced, so invalidate them
			end

			self[id2][id] = nil -- throw away paired IDs' references to link arrays...
		end

		self[id] = nil -- ...along with those from the removed ID
	end
end

--- DOCME
-- @treturn LinkCollection
function M.New ()
	return setmetatable({}, LinkCollection)
end

return M