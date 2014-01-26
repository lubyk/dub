project ( dub NONE )

cmake_minimum_required ( VERSION 2.8 )

include ( cmake/dist.cmake )
include ( lua )

install (
  DIRECTORY dub/
  DESTINATION ${INSTALL_LMOD}/dub
  COMPONENT Runtime
)

install_data ( README.md LICENSE )

# install_example ( examples/ )
