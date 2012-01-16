require 'lubyk'

if arg[1] == '--speed' then
  test.speed = true
end
test.files(lk.dir(), '%_test.lua$')
