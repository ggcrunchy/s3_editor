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
function UndoRedoStack:IsDirty ()
	return self.m_pos ~= self.m_sync
end

--- DOCME
function UndoRedoStack:Push (undo, redo, object)
	local count, pos, size = self.m_count, self.m_pos, self.m_size

	if pos < size then
		pos = pos + 1
	else
		pos = 1
	end

	if count < size then
		self.m_count = count + 1
	end

	if pos == self.m_sync then
		self.m_sync = nil -- full lap: no longer possible to undo back to synchronization
	end

	local offset = (pos - 1) * 3

	self[#self + 1] = undo
	self[#self + 1] = redo
	self[#self + 1] = object or false
end

--- DOCME
function UndoRedoStack:Redo ()
end

--- DOCME
function UndoRedoStack:Synchronize ()
end

--- DOCME
function UndoRedoStack:Undo ()
	
end

--- DOCME
-- @uint n
-- @treturn UndoRedoStack S
function M.New (n)
	assert(n > 0, "Invalid size")

	local stack = { m_count = 0, m_pos = 1, m_size = n, m_sync = 1 }

	return setmetatable(stack, UndoRedoStack)
end

return M