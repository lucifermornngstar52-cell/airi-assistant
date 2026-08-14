cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

if(NOT EXISTS ${EPHEMERAL_DIR})
  message(FATAL_ERROR "Flutter ephemeral directory not found. Run flutter pub get.")
endif()

file(STRINGS ${EPHEMERAL_DIR}/flutter_ephemeral_library.info FLUTTER_EPHEMERAL_LIBRARY)

add_library(flutter INTERFACE)
target_link_libraries(flutter INTERFACE ${FLUTTER_EPHEMERAL_LIBRARY})
target_include_directories(flutter INTERFACE ${EPHEMERAL_DIR})
