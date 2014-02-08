cmake_minimum_required(VERSION 2.8)
# --------------------------------------------------------------
#  dub
# --------------------------------------------------------------
set(MODULE_NAME dub)
set(target ${MODULE_NAME})

# Where to install files
set(INSTALL_PATH "${CMAKE_BINARY_DIR}/lib" CACHE STRING "Install directory path")
# -------- PLAT

set(LINK_LIBS )

if(UNIX)
  if(APPLE)
    set(PLAT "macosx")
    set(LINK_FLAGS "-bundle -undefined dynamic_lookup -all_load")
  else(APPLE)
    set(PLAT "linux")
    set(LINK_FLAGS "-shared")
  endif(APPLE)
else(UNIX)
  if(WIN32)
    set(PLAT "win32")
  else(WIN32)
    set(PLAT "unsupported")
  endif(WIN32)
endif(UNIX)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -Wall -fPIC -O2")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -Wall -fPIC -O2")
if (RELEASE)
  add_definitions(-O2 -DNDEBUG)
endif(RELEASE)

# --------------------------------------------------------------
#  module
# --------------------------------------------------------------
add_custom_target(${MODULE_NAME} true)

# --------------------------------------------------------------
#  install                                     
# --------------------------------------------------------------
install(DIRECTORY ${MODULE_NAME}
  DESTINATION ${INSTALL_PATH}
)
