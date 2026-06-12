cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "media_metadata")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# Correctif global pour l'erreur PDB C1090
if(MSVC)
  add_compile_options(/FS)
endif()

set(PLUGIN_NAME "media_metadata_plugin")

add_library(${PLUGIN_NAME} SHARED
  "media_metadata_plugin.cpp"
  "media_metadata_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Windows Media Foundation libs
target_link_libraries(${PLUGIN_NAME} PRIVATE
  mfplat
  mfreadwrite
  mfuuid
  propsys
  shlwapi
)

set(media_metadata_bundled_libraries
  ""
  PARENT_SCOPE
)