# ----------------------------------------------------------------------------
#  CMake file for Lua. See root CMakeLists.txt
#
# ----------------------------------------------------------------------------
project(lua)

include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# ----------------------------------------------------------------------------------
# 				Define the library target:
# ----------------------------------------------------------------------------------

set(the_target "lua")

file(GLOB lib_srcs *.c)
list (REMOVE_ITEM lib_srcs ${CMAKE_CURRENT_SOURCE_DIR}/lua.c ${CMAKE_CURRENT_SOURCE_DIR}/luac.c)
file(GLOB lib_hdrs *.h)
set(lib_ext_hdrs)

add_library(${the_target} STATIC ${lib_srcs} ${lib_hdrs} ${lib_ext_hdrs})

set_target_properties(${the_target}
	PROPERTIES OUTPUT_NAME "${the_target}"
	ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/vendor_lib
	)
