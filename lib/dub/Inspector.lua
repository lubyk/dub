--[[------------------------------------------------------

  dub.Inspector
  -------------

  The Inspector 'knows' about the functions and classes
  and can answer queries. It first the main entry point to
  parse and create bindings.

--]]------------------------------------------------------
local lib     = {
  type = 'dub.Inspector',
  DOXYGEN_CMD = 'doxygen',
}
local private = {}
lib.__index   = lib
dub.Inspector = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib, opts)
    local self = {db = dub.MemoryStorage()}
    setmetatable(self, lib)
    if opts then
      self:parse(opts)
    end
    return self
  end
})

--=============================================== PUBLIC METHODS
-- Add xml headers to the database. If not_lazy is set, parse everything
-- directly (not when needed). Only set this option if the xml files
-- will be removed before queries.
function lib:parseXml(xml_dir, not_lazy, ignore_list)
  self.db:parse(xml_dir, not_lazy, ignore_list)
end

function lib:parse(opts)
  if type(opts) == 'string' then
    opts = {INPUT = opts}
  end
  assert(opts.INPUT, "Missing 'INPUT' field")

  if opts.html then
    opts.GENERATE_HTML = 'YES'
    opts.keep_xml = true
  end

  local doc_dir = opts.doc_dir
  if opts.keep_xml and not doc_dir then
    doc_dir = 'dub-doc'
  elseif not doc_dir then
    doc_dir = 'dub-tmp'
    local i = 0
    while true do
      if lk.exist(doc_dir) then
        i = i + 1
        doc_dir = string.format('dub-tmp-%i', i)
      else
        break
      end
    end
  end

  private.execute('mkdir -p ' .. doc_dir)

  local doxypath = opts.Doxyfile
  if not doxypath then
    doxypath = doc_dir .. '/Doxyfile'
    local doxyfile = io.open(doxypath, 'w')

    local doxytemplate = dub.Template {path = lk.scriptDir() .. '/Doxyfile'}
    if type(opts.INPUT) == 'table' then
      opts.INPUT = lk.join(opts.INPUT, ' ')
    end
    if type(opts.PREDEFINED) == 'table' then
      opts.PREDEFINED = lk.join(opts.PREDEFINED, ' \\\n                         ')
    end

    -- Generate Doxyfile
    doxyfile:write(doxytemplate:run({doc_dir = doc_dir, opts = opts}))
    doxyfile:close()
  end

  -- Generate xml
  self:doxygen(doxypath)
  -- Parse xml
  self:parseXml(doc_dir .. '/xml', true, opts.ignore)
  if not opts.keep_xml then
    if not opts.doc_dir then
      lk.rmTree(doc_dir, true)
    else
      lk.rmTree(doc_dir .. '/xml', true)
    end
  end
end

function lib:doxygen(doxyfile)
  private.execute(self.DOXYGEN_CMD .. ' ' .. doxyfile)
end

-- A class in a namespace is queried with 'std::string'.
function lib:find(name)
  -- A 'child' of the Inspector can be anything so we
  -- have to walk through the files to find what we
  -- are asked for.
  -- Object lives at the root of the name space.
  return self.db:findByFullname(name)
end

-- Return an interator on all children known to the inspector.
function lib:children()
  return self.db:children()
end

--- Try to follow typedefs to resolve a type
function lib:resolveType(name)
  return self.db:resolveType(self.db, name)
end
--=============================================== PRIVATE

function private.execute(cmd)
  os.execute(cmd)
end

