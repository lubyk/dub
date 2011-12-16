--[[------------------------------------------------------

  dub.Dir
  --------

  This is a helper to access/glob directory trees.
  (stolen from lubyk)

--]]------------------------------------------------------
require 'lfs'

local lib = {sep = '/', ignore_pattern = '^[.]', type='dub.Dir'}
lib.__index = lib
dub.Dir = lib

setmetatable(lib, {
  -- new method
 __call = function(lib, path)
  local self = {path = path}
  setmetatable(self, lib)
  return self
end})

local function glob_list(base, pattern)
  for file in lfs.dir(base) do
    if not string.match(file, lib.ignore_pattern) then
      local fullpath = base..lib.sep..file
      local attrs = lfs.attributes(fullpath)
      if attrs and attrs.mode == 'file' then
        if not pattern or string.match(fullpath, pattern) then
          coroutine.yield(fullpath)
        end
      elseif attrs and attrs.mode == 'directory' then
        glob_list(fullpath, pattern)
      end
    end
  end
end

--- Recursively parse the directory to find files matching the pattern.
function lib:glob(pattern)
  local co = coroutine.create(glob_list)
  --glob_list(self.path, pattern, list)
  return function()
    local ok, value = coroutine.resume(co, self.path, pattern)
    if ok then
      return value
    else
      return nil
    end
  end
end

local function list_files(self)
  local base = self.path
  for file in lfs.dir(base) do
    if not string.match(file, self.ignore_pattern) then
      coroutine.yield(base..self.sep..file)
    end
	end
end
--- Return a table with a list of paths in the directory.
-- The returned values are paths, not just filenames.
function lib:list()
  local co = coroutine.create(list_files)
  return function()
    local ok, value = coroutine.resume(co, self)
    if ok then
      return value
    else
      return nil
    end
  end
end


