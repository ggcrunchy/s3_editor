--- This class provides functionality for linking nodes, cf. @{NodePattern}.
--
-- The **Object** type is user-defined; the implementation makes only a basic assumption
-- about its lifetime, q.v. @{Links:__cons}.
--
-- This is not a singleton class; object relationships, as described by its methods, are
-- restricted to those related to a particular instance. A given object may belong to
-- two or more instances, say, yet its links will be unique in each.
-- @module Links

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
local type = type
local yield = coroutine.yield

-- Modules --
local array_funcs = require("tektite_core.array.funcs")
local class = require("tektite_core.class")
local coro = require("iterator_ops.coroutine")
local strings = require("tektite_core.var.strings")

-- Unique member keys (Links) --
local _pair_links = {}
local _proxies = {}

-- Unique member keys (SingleLink) --
local _on_break = {}
local _parent = {}
local _proxy1 = {}
local _proxy2 = {}
local _sub1 = {}
local _sub2 = {}

-- Nothing to iterate
local function NoOp () end

-- Iterate over the non-string keys in the table
local function NumberPairs (t, k)
	repeat
		k = next(t, k)
	until k == nil or type(k) == "number"

	return k, t[k]
end

-- Helper to visit a proxy's link keys
local function LinkKeys (proxy)
	if proxy then
		return NumberPairs, proxy
	else
		return NoOp
	end
end

-- Gets the key for a proxy pairing
local function GetKey (p1, p2)
	return p1[p2.id]
end

-- Iterates over all the links between two proxies
local function LinksIter (L, p1, p2)
	local key = GetKey(p1, p2)
	local t = key and L[_pair_links][key]

	if t then
		return ipairs(t)
	else
		return NoOp
	end
end

-- Helper to remove an object and all its associated data
local function RemoveObject (L, id, object)
	local pair_links, proxies = L[_pair_links], L[_proxies]

	-- Invalidate the proxy and break any links associated with the object. The order is
	-- important: with the proxy gone, recursive removals are avoided in the break logic.
	local proxy = proxies[object]

	proxies[object], proxy.id = nil

	for _, v in LinkKeys(proxy) do
		for _, link in ipairs(pair_links[v]) do
			link:Break()
		end
	end
--[[
	-- Perform any user-defined remove logic.
	local on_remove = L[_on_remove]

	if on_remove then
		on_remove(object)
	end
]]
	-- Evict the object.
--	L[_objects]:RemoveAt(id)
end
--[[
-- Helper to get an object (if valid) from a proxy
local function Object (L, proxy)
	local id = proxy and proxy.id

	if id then
		return L[_objects]:Get(id)
	end

	return nil
end
]]
-- Forward reference to Links class --
local LinksClass

-- SingleLink class definition --
local SingleLinkClass = class.Define(function(Link)
	-- Helper to find a link for a proxy pair
	local function FindLink (parent, p1, p2, link)
		for i, v in LinksIter(parent, p1, p2) do
			if v == link then
				return i
			end
		end
	end

	--- Breaks this link.
	--
	-- If it is already broken, this is a no-op.
	-- @see Link:IsIntact
	function Link:Break ()
		local parent, p1, p2 = self[_parent], self[_proxy1], self[_proxy2]

		-- With the proxies now safely cached (if still present), clear the proxy fields to abort
		-- recursion (namely, in case of dead objects).
		self[_proxy1], self[_proxy2] = nil

		-- If both objects were valid, the link is still intact. If so, remove it from the pair's
		-- list. If doing this empties the list itself, remove it also, as well as its associated
		-- key from each proxy.
		local obj1 = Object(parent, p1)
		local obj2 = Object(parent, p2)
		-- ^^ TODO: if parent still set, go there

		if obj1 ~= nil and obj2 ~= nil then
			local key, pair_links = GetKey(p1, p2), parent[_pair_links]
			local links = pair_links[key]

			array_funcs.Backfill(links, FindLink(parent, p1, p2, self))

			if #links == 0 then
				pair_links[key], p1[p2.id], p2[p1.id] = nil
			end
		end

		-- If the link went from intact to broken, call any handler.
		local on_break = p1 and self[_on_break]

		if on_break then
		--	on_break(self, obj1, obj2, self[_sub1], self[_sub2])
		end
	end

	--- Getter.
	-- @treturn boolean The link is still intact?
	--
	-- When **false**, this is the only return value.
	-- @treturn ?Object Linked object #1...
	-- @treturn ?Object ...and #2.
	-- @treturn ?string Sublink of object #1...
	-- @treturn ?string ...and object #2.
	-- @see Link:IsIntact
	function Link:GetObjects ()
		local parent = self[_parent]
		local obj1, obj2 = Object(parent, self[_proxy1]), Object(parent, self[_proxy2])

		if obj1 and obj2 then
			return true, obj1, obj2, self[_sub1], self[_sub2]
		end

		return false
	end

	--- Getter.
	-- @tparam Object object Object, which may be paired in the link.
	-- @treturn ?Object If the link is intact and _object_ was one of its linked objects, the
	-- other object; otherwise, **nil**.
	-- @treturn ?string If an object was returned, its sublink; if absent, **nil**.
	-- @see Links:LinkObjects
	function Link:GetOtherObject (object)
		local _, obj1, obj2, sub1, sub2 = self:GetObjects()

		if obj1 == object then
			return obj2, sub2
		elseif obj2 == object then
			return obj1, sub1
		end

		return nil
	end

	--- Checks whether a link is not yet broken. Links are broken after @{Link:Break}.
	-- @treturn boolean The link is still intact?
	-- @see Links:LinkObjects
	function Link:IsIntact ()
		local parent = self[_parent]

		return (Object(parent, self[_proxy1]) and Object(parent, self[_proxy2])) ~= nil
	end

	--- Sets logic to call when a link breaks, cf. @{Link:IsIntact}.
	--
	-- Called as
	--    func(link, object1, object2, sub1, sub2)
	-- where _object1_ and _object2_ were the linked objects and _sub1_ and _sub2_ were their
	-- respective sublinks.
	--
	-- **N.B.** This may be triggered lazily, i.e. outside of @{Link:Break}, either via some
	-- other method of **Link** or @{Links:CleanUp}.
	-- @callable func Function to assign, or **nil** to disable the logic.
	function Link:SetBreakFunc (func)
	--	self[_on_break] = func
	end

	--- Class constructor.
	-- @tparam Links parent
	-- @tparam Proxy proxy1 Proxy to **Object** #1...
	-- @tparam Proxy proxy2 ...and #2.
	-- @string sub1 Sublink corresponding to _proxy1_...
	-- @string sub2 ...and _proxy2_.
	function Link:__cons (parent, proxy1, proxy2, sub1, sub2)
		assert(class.Type(parent) == LinksClass, "Non-links parent")

		self[_parent] = parent
		self[_proxy1] = proxy1
		self[_proxy2] = proxy2
		self[_sub1] = sub1
		self[_sub2] = sub2
	end
end)

-- Links class definition --
LinksClass = class.Define(function(Links)
	-- Does the first sublink match the link?
	local function Match1 (link, proxy, sub)
		return link[_proxy1] == proxy and link[_sub1] == sub
	end

	-- Does the second sublink match the link?
	local function Match2 (link, proxy, sub)
		return link[_proxy2] == proxy and link[_sub2] == sub
	end

	-- Helper to get a proxy (if valid) from an object
	local function Proxy (L, object)
		return object ~= nil and L[_proxies][object]
	end

	--- Getter.
	-- @tparam Object object
	-- @string sub Sublink 
	-- @treturn uint Number of links to _object_ through _sub_.
	function Links:CountLinks (object, sub)
		local proxy, pair_links, count = Proxy(self, object), self[_pair_links], 0

		for _, v in LinkKeys(proxy) do
			for _, link in ipairs(pair_links[v]) do
				if Match1(link, proxy, sub) or Match2(link, proxy, sub) then
					count = count + 1
				end
			end
		end

		return count
	end

	-- Are the proxied objects already linked through the given sublinks?
	local function AlreadyLinked (L, p1, p2, sub1, sub2)
		for _, link in LinksIter(L, p1, p2) do
			if Match1(link, p1, sub1) and Match2(link, p2, sub2) then
				return true
			end
		end
	end

	-- Sorts a prospective link pair, to forgo some confusion about their lookup key
	local function SortProxies (p1, p2, sub1, sub2, obj1, obj2)
		if p2.id < p1.id then
			return p2, p1, sub2, sub1, obj2, obj1
		else
			return p1, p2, sub1, sub2, obj1, obj2
		end
	end
--[[
	--- Predicate.
	-- @tparam Object object1
	-- @tparam Object object2
	-- @string sub1 Sublink corresponding to _object1_...
	-- @string sub2 ...and _object2_.
	-- @treturn boolean The link can be made? If **true**, this is the only return value.
	-- @treturn ?string Reason link cannot be formed.
	-- @treturn ?boolean This is a contradiction or "strong" failure, i.e. the predicate will
	-- **always** fail, given the inputs?
	function Links:CanLink (object1, object2, sub1, sub2)
		local p1, p2 = Proxy(self, object1), Proxy(self, object2)

		-- Both objects are still valid?
		if p1 and p2 then
			p1, p2, sub1, sub2, object1, object2 = SortProxies(p1, p2, sub1, sub2, object1, object2)

			if p1 == p2 or AlreadyLinked(self, p1, p2, sub1, sub2) then
				return false, p1 == p2 and "Same object" or "Already linked"

			-- ...and not already linked?
			else
				local tag_db = self[_tag_db]

				-- ...pass all object1-object2 predicates?
				local passed, why, is_cont = tag_db:CanLink(p1.name, p2.name, object1, object2, sub1, sub2, self)

				if passed then
					-- ...and object2-object1 ones too?
					passed, why, is_cont = tag_db:CanLink(p2.name, p1.name, object2, object1, sub2, sub1, self)

					if passed then
						return true
					end
				end

				return false, why, is_cont
			end
		end

		return false, "Invalid object", true
	end

	--- Getter.
	-- @tparam Object object
	-- @treturn ?string If _object_ is valid and has been assigned a tag by @{Links:SetTag},
	-- that tag; otherwise, **nil**.
	function Links:GetTag (object)
		local proxy = Proxy(self, object)

		return proxy and proxy.name
	end
]]
	--- Predicate.
	-- @tparam Object object
	-- @string sub
	-- @treturn boolean X
	function Links:HasLinks (object, sub)
		local proxy, pair_links = Proxy(self, object), self[_pair_links]

		for _, v in LinkKeys(proxy) do
			for _, link in ipairs(pair_links[v]) do
				if Match1(link, proxy, sub) or Match2(link, proxy, sub) then
					return true
				end
			end
		end

		return false
	end

	--- DOCME
	-- @tparam Object object1
	-- @tparam Object object2
	-- @string sub1
	-- @string sub2
	-- @treturn ?Link L
	-- @treturn ?string S
	-- @treturn ?boolean B
	function Links:LinkObjects (object1, object2, sub1, sub2)
		local can_link, why, is_cont = self:CanLink(object1, object2, sub1, sub2) 

		if can_link then
			local proxies, p1, p2 = self[_proxies]

			-- To limit a few checks later on, impose an order on the proxies.
			p1, p2, sub1, sub2 = SortProxies(proxies[object1], proxies[object2], sub1, sub2)

			-- Consult the links already associated with this pairing. If none yet exist, generate
			-- a key and list and hook everything up.
			local key, pair_links = GetKey(p1, p2), self[_pair_links]
			local links = pair_links[key]

			if not key then
				key, links = strings.PairToKey(p1.id, p2.id), {}

				pair_links[key], p1[p2.id], p2[p1.id] = links, key, key
			end

			-- Install the link.
			local link = SingleLinkClass(self, p1, p2, sub1, sub2)

			links[#links + 1] = link

			return link
		end

		return nil, why, is_cont
	end

	--- DOCME
	-- @function Links:Links
	-- @tparam Object object
	-- @string sub
	-- @treturn iterator X
	Links.Links = coro.Iterator(function(L, object, sub)
		local proxy, pair_links = Proxy(L, object), L[_pair_links]

		for _, v in LinkKeys(proxy) do
			for _, link in ipairs(pair_links[v]) do
				if Match1(link, proxy, sub) or Match2(link, proxy, sub) then
					yield(link)
				end
			end
		end
	end)

	--- DOCME
	-- @tparam Object object
	function Links:RemoveTag (object)
		local proxy = Proxy(self, object)

		if proxy then
			RemoveObject(self, proxy.id, object)
		end
	end
--[[
	--- Setter.
	-- @callable func X
	function Links:SetAssignFunc (func)
		self[_on_assign] = func
	end

	--- Setter.
	-- @callable func X
	function Links:SetRemoveFunc (func)
		self[_on_remove] = func
	end
]]
--[[
	--- DOCME
	-- @tparam Object object
	-- @string name
	function Links:SetTag (object, name)
		assert(object ~= nil, "Invalid object")
		assert(self[_tag_db]:Exists(name), "Tag does not exist")

		-- Associate a fresh proxy with the object. Put it in the object list.
		local proxies = self[_proxies]

		assert(not proxies[object], "Object already tagged")

		local proxy = { id = self[_objects]:Insert(object), name = name }

		proxies[object] = proxy

		-- Perform any user-defined assign logic.
		local on_assign = self[_on_assign]

		if on_assign then
			on_assign(object)
		end
	end
]]
	--- Class constructor.
	function Links:__cons ()
		-- Since objects will tend to be GC objects, e.g. tables or userdata, some care is taken
		-- to avoid reference cycles. The layout and considerations are as follows:
		--
		-- pair_links: Map, key(id #1, id #2) -> Array of links. Each key is built from two linked
		-- objects' ID's (i.e. their positions in the objects array); the corresponding array value
		-- holds all links between those same objects.
		-- ^^ TODO: array-of-array of links, fetch from free list on creation, else reuse
		-- use tostring(id)'d order for link members
		-- array-of-array probably doesn't buy us much (even worth keeping in list?)
		-- ^^ could even lazily unload empty pairs
		--
		-- proxies: Map, object reference -> { object id, tag name, proxy_links }. The value (i.e.
		-- proxy) contains the ID of the proxied object (i.e. its position in the objects array),
		-- the object's tag, and a list of objects, described next.
		-- ^^ TODO: no tag name... pair links, not sure if id can be maintained independently

		-- in theory should simplify CountLinks() and HasLinks()... hmm, unless broken?
		-- ^^ argh, then links do need the parent
		-- ^^^ actually probably fine, but see about pulling non-node info into that

		self[_pair_links] = {}
		self[_proxies] = {}
	end
end)

return LinksClass