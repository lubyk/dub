require 'lubyk'

dub.warn_level = 4

if arg[1] == '--speed' then
  test.speed = true
end
test.files(lk.scriptDir(), '%_test.lua$')
