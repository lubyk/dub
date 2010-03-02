require 'dub'
require 'dub/lua'
require 'pathname'

doxy = Dub.parse(Pathname(__FILE__).dirname + 'xml/namespacedoxy.xml')[:doxy]

Dub::Lua.bind(doxy)

File.open(Pathname(__FILE__).dirname + "bindings/all_lua.cpp", 'wb') do |f|
  %w{Matrix FloatMat}.each do |name|
    f.puts doxy[name]
  end
end
