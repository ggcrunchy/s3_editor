--- Public strings used by the editor.

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

local Strings = {}

-- Principal command bar --
Strings.commands = [[
The box may be dragged around via the title bar.

Pressing the '?' will highlight any help-equipped objects. Drag and release it over one of these to call up help text like this.

The string to its right shows the current level name, if any. A trailing asterisk indicates that the level has been modified since it was created or last saved.

Principal commands are available under the 'Actions' dropdown:

'Test' attempts to build the level, launching it in the game on success.
'Build' verifies the level. If this passes, the level is built in game-loadable form.
'Verify' checks the level for errors that would prevent a build, reporting any in the log.
'Save' saves the current work-in-progress level, making it available from the editor launch scene.

Click on the 'x' to request the editor close.]]

-- Navigation command bar --
Strings.navigation = [[
The box may be dragged around via the title bar.

Click on the various headings to go to the respective view or open a dropdown where such views may be selected.]]

-- Export the module.
return function(what)
	return Strings[what] -- TODO: choose for current language
end