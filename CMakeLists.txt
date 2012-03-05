set(MODULE_NAME dub)
# --------------------------------------------------------------

# --------------------------------------------------------------
#  module
# --------------------------------------------------------------
add_custom_target(${MODULE_NAME} true)
file(MAKE_DIRECTORY ${LUBYK_LIB}/${MODULE_NAME})

# --------------------------------------------------------------
#  module_lib                                  module/xxxx.lua
# --------------------------------------------------------------
add_custom_target("${MODULE_NAME}_lib" ALL
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/lib ${LUBYK_LIB}
)
add_dependencies(${MODULE_NAME} "${MODULE_NAME}_lib")

