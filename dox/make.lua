require 'lubyk'

local ins  = dub.Inspector {
  INPUT    = lk.scriptDir(),
  doc_dir  = lk.scriptDir() .. '/../doc',
  html     = true,
}

