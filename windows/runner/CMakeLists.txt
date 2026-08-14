cmake_minimum_required(VERSION 3.14)
project(airi_assistant LANGUAGES CXX)

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "runner.cpp"
  "runner.exe.manifest"
  "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral/flutter_windows.dll"
)

apply_standard_settings(${BINARY_NAME})

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE comdlg32)

add_custom_target(copy_flutter_assets ALL
  COMMAND ${CMAKE_COMMAND} -E copy_directory
  "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral/flutter_assets"
  "${CMAKE_BINARY_DIR}/runner/data/flutter_assets"
  DEPENDS flutter
)

if(PLUGIN_ENABLED)
  add_custom_target(copy_plugins ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral/plugins"
    "${CMAKE_BINARY_DIR}/runner/data/flutter_assets"
    DEPENDS flutter
  )
endif()

set_target_properties(${BINARY_NAME} PROPERTIES OUTPUT_NAME "airi_assistant")
