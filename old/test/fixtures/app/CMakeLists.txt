cmake_minimum_required(VERSION 2.6)
# ----------------------------------------------------------------------------
#  CMake file for Lua. See root CMakeLists.txt
#
# ----------------------------------------------------------------------------
project(Matrix)

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/vendor/lua
  ${CMAKE_CURRENT_SOURCE_DIR}/../../../lib/dub/lua
)

# ==============================================================================
#
#  Platform guessing
#
# ==============================================================================
if(UNIX)
  if(APPLE)
    # macosx
    set(PLAT_LINK "-bundle -undefined dynamic_lookup -all_load")
  else(APPLE)
    # linux
    set(PLAT_LINK "-shared")
  endif(APPLE)
else(UNIX)
  if(WIN32)
    # ?
  else(WIN32)
    # ?
  endif(WIN32)
endif(UNIX)

# ----------------------------------------------------------------------------------
# 				Define the library target:
# ----------------------------------------------------------------------------------

set(the_target "Matrix")

file(GLOB lib_srcs bindings/*.cpp)
file(GLOB lib_hdrs bindings/*.h)
set(lib_ext_hdrs)

set(CMAKE_CXX_FLAGS "-DLUA_USE_DLOPEN -DLUA_USE_POSIX")
add_library(${the_target} STATIC ${lib_srcs} ${lib_hdrs} ${lib_ext_hdrs})

set_target_properties(${the_target}
	PROPERTIES OUTPUT_NAME "${the_target}"
	#LINK_FLAGS ${PLAT_LINK}
	PREFIX ""
	SUFFIX ".a" #".so"
	LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/vendor/lua
	)