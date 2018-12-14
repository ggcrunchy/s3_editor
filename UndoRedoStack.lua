--- A mechanism for managing undo and redo operations.
-- @module UndoRedoStack

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
local setmetatable = setmetatable

-- Exports --
local M = {}

--
--
--

local UndoRedoStack = {}

UndoRedoStack.__index = UndoRedoStack

--- DOCME
-- @treturn boolean X
function UndoRedoStack:IsSynchronized ()
	return self.m_stack_pos == self.m_sync
end

local function IncArrayPos (S)
	local old, new = S.m_array_pos

	if old < S.m_size then
		new = old + 1
	else
		new = 1
	end

	S.m_array_pos = new

	return new, old
end

local function AuxPush (S, func, object)
	local _, old = IncArrayPos(S)
	local offset = (old - 1) * 2

	S[offset + 1] = func
	S[offset + 1] = object or false
end

local function PutStackPosAtEnd (S, count)
	S.m_count, S.m_stack_pos = count, count + 1
end

--- DOCME
-- @callable func
-- @param[opt=false] object
function UndoRedoStack:Push (func, object)
	AuxPush(self, func, object)

	local count, spos, sync = self.m_count, self.m_stack_pos, self.m_sync

	if spos <= count then -- have performed some undos?
		if sync and sync > spos then -- sync point now unreachable?
			self.m_sync = nil
		end

		PutStackPosAtEnd(self, count + 1)
	elseif count < self.m_size then -- room to grow?
		PutStackPosAtEnd(self, count + 1)
	elseif sync then -- first item evicted, so update sync point
		sync = sync - 1

		if sync > 0 then -- still reachable?
			self.m_sync = sync
		else
			self.m_sync = nil
		end
	end
end

local function Call (S, pos, how)
	local offset = (pos - 1) * 2

	S[offset + 1](how, S[offset + 2])
end

--- DOCME
function UndoRedoStack:Redo ()
	local spos = self.m_stack_pos
	local can_redo = spos < self.m_count

	if can_redo then
		self.m_stack_pos = spos + 1

		Call(self, IncArrayPos(self), "redo")
	end

	return can_redo
end

--- DOCME
function UndoRedoStack:Synchronize ()
	self.m_sync = self.m_stack_pos
end

--- DOCME
function UndoRedoStack:Undo ()
	local spos = self.m_stack_pos
	local can_undo = spos > 1

	if can_undo then
		self.m_stack_pos = spos - 1

		local old = self.m_array_pos

		Call(self, old, "undo")

		if old > 1 then
			old = old - 1
		else
			old = self.m_size -- array and stack pos differ, so ring known to be full
		end

		self.m_array_pos = old
	end

	return can_undo
end

--- DOCME
-- @uint n
-- @treturn UndoRedoStack S
function M.New (n)
	assert(n > 0, "Invalid size")

	local stack = {
		m_array_pos = 1, -- absolute position in underlying array
		m_stack_pos = 1, -- relative position in ring-based stack
		m_count = 0, m_size = n, -- current stack usage; maximum available
		m_sync = 1 -- relative position where stack would be synchronized (may be nil)
	}

	return setmetatable(stack, UndoRedoStack)
end

return M