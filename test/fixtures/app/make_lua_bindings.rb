require 'dub'
require 'dub/lua'
require 'pathname'

doxy = Dub.parse(Pathname(__FILE__).dirname + 'xml/namespacedoxy.xml')[:doxy]

Dub::Lua.bind(doxy)

File.open(Pathname(__FILE__).dirname + 'bindings/Matrix_lua.cpp', 'wb') do |f|
  f.puts doxy[:Matrix].to_s
end
