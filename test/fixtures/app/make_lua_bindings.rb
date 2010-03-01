require 'doxy_generator'
require 'doxy_generator/lua'
require 'pathname'

doxy = DoxyGenerator.parse(Pathname(__FILE__).dirname + 'xml/namespacedoxy.xml')[:doxy]

DoxyGenerator::Lua.bind(doxy)

File.open(Pathname(__FILE__).dirname + 'bindings/Matrix_lua.cpp', 'wb') do |f|
  f.puts doxy[:Matrix].to_s
end
