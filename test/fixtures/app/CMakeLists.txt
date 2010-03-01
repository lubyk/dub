# ----------------------------------------------------------------------------
#  CMake file for Lua. See root CMakeLists.txt
#
# ----------------------------------------------------------------------------
project(Matrix)

include_directories(${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../lua)

# ----------------------------------------------------------------------------------
# 				Define the library target:
# ----------------------------------------------------------------------------------

set(the_target "Matrix")

file(GLOB lib_srcs Matrix_bindings/*.cpp)
file(GLOB lib_hdrs Matrix_bindings/*.h)
set(lib_ext_hdrs)

add_library(${the_target} ${lib_srcs} ${lib_hdrs} ${lib_ext_hdrs})
