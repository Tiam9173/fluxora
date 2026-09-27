# Fluxora Loopback Manager.
#
# Copyright (C) 2026 Fluxora Contributors
# GPL-3.0-or-later. See the LICENSE file at the repository root.
#
# This target builds in two modes:
#   1. as a subdirectory of windows/CMakeLists.txt (part of the Flutter Windows
#      app build) - installed next to Fluxora.exe by the parent;
#   2. standalone, which is how D5.2-impl validated it:
#        cmake -S windows/fluxora_loopback -B <dir> -G Ninja -DCMAKE_BUILD_TYPE=Release
#        cmake --build <dir>
#
# FirewallAPI is resolved at run time with LoadLibraryW(), so no FirewallAPI.lib
# import library is required (the Windows SDK does not ship one).

cmake_minimum_required(VERSION 3.20)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(FluxoraLoopbackManager LANGUAGES CXX RC)
endif()

add_executable(FluxoraLoopbackManager WIN32
  main.cpp
  loopback_manager.cpp
  resource.rc
)

target_compile_features(FluxoraLoopbackManager PRIVATE cxx_std_17)

target_compile_definitions(FluxoraLoopbackManager PRIVATE
  UNICODE
  _UNICODE
  NOMINMAX
  WIN32_LEAN_AND_MEAN
  _WIN32_WINNT=0x0A00
)

# comctl32 for the list view, shell32 for CommandLineToArgvW, advapi32 for SID
# helpers, user32/gdi32 for the window itself.
target_link_libraries(FluxoraLoopbackManager PRIVATE
  comctl32
  user32
  gdi32
  shell32
  advapi32
)

# Standalone builds drop the artifact in <build>/bin. When built as part of the
# Flutter app the parent controls the layout and installs the executable next to
# Fluxora.exe.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  set_target_properties(FluxoraLoopbackManager PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  )
endif()
