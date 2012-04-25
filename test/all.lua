require 'lubyk'

if arg[1] == '--speed' then
  test.speed = true
end
test.files(lk.scriptDir(), '%_test.lua$')
