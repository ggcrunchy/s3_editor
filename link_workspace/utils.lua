--- Link utilities.

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

-- Corona globals --
local display = display

-- Unique member keys --
local _link_scene = {}

-- Exports --
local M = {}

--
--
--

local function AuxRemoveLinkScene (event)
    event.target[_link_scene] = false
end

--- DOCME
-- @pobject object
-- @tparam LinkScene scene
function M.AttachLinkScene (object, link_scene)
    object[_link_scene] = link_scene

    object:addEventListener("finalize", AuxRemoveLinkScene)
end

--- DOCME
function M.FindLinkScene (object)
    local stage = display.getCurrentStage()

    while true do
        local link_scene = object[_link_scene]

        if link_scene ~= nil then
            return assert(link_scene, "Link scene-bearing object has been removed")
        end

        assert(object ~= stage, "No link scene attached")

        object = assert(object.parent, "Object not in hierarchy")
    end
end

return M