require 'dub'
require 'dub/lua'
require 'pathname'

dub = Dub.parse(Pathname(__FILE__).dirname + 'xml/namespacedub.xml')[:dub]

Dub::Lua.bind(dub)

File.open(Pathname(__FILE__).dirname + "bindings/all_lua.cpp", 'wb') do |f|
  %w{Matrix FloatMat}.each do |name|
    f.puts dub[name]
  end
end
