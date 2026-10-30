cmake_minimum_required(VERSION 3.26)

project(luna-compositor VERSION 0.2.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

# The waylib fork is installed here by vendor/build-waylib.sh.
set(LUNA_VENDOR_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/vendor-prefix" CACHE PATH "Install prefix of the waylib fork")
list(PREPEND CMAKE_PREFIX_PATH "${LUNA_VENDOR_PREFIX}")
set(ENV{PKG_CONFIG_PATH} "${LUNA_VENDOR_PREFIX}/lib/pkgconfig:${LUNA_VENDOR_PREFIX}/share/pkgconfig:$ENV{PKG_CONFIG_PATH}")

option(LUNA_BUILD_WAYLIB "Build luna-compositor on the waylib fork" ON)
option(LUNA_BUILD_QT "Build luna-compositor-qt on QtWaylandCompositor (test harness)" ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_SERVER REQUIRED IMPORTED_TARGET wayland-server)

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

# qml/Layout.js is shared by both compositors; in Luna.Server it sits at qml/Layout.js.

# ---------------------------------------------------------------------------
# luna-compositor-qt: the QtWaylandCompositor spike, kept as a test harness.
# ---------------------------------------------------------------------------
if(LUNA_BUILD_QT)
    find_package(Qt6 REQUIRED COMPONENTS WaylandCompositor WaylandCompositorPrivate)
    find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

    qt_add_executable(luna-compositor-qt
        src/main.cpp
        src/frame_log.cpp
        src/layer_shell.h
        src/layer_shell.cpp
        src/foreign_toplevel.h
        src/foreign_toplevel.cpp
        src/session_lock.h
        src/session_lock.cpp
        src/surface_integration.h
    )

    # Server code for the protocols that QtWaylandCompositor lacks.
    qt6_generate_wayland_protocol_server_sources(luna-compositor-qt PRIVATE_CODE FILES
        ${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-layer-shell-unstable-v1.xml
        ${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-foreign-toplevel-management-unstable-v1.xml
        ${CMAKE_CURRENT_SOURCE_DIR}/protocols/ext-session-lock-v1.xml
    )

    # Only the wl_interface tables of xdg-shell; Qt keeps its own copy hidden.
    set(XDG_SHELL_XML /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml)
    set(XDG_SHELL_C ${CMAKE_CURRENT_BINARY_DIR}/xdg-shell-interfaces.c)
    add_custom_command(OUTPUT ${XDG_SHELL_C}
        COMMAND ${WAYLAND_SCANNER} private-code ${XDG_SHELL_XML} ${XDG_SHELL_C}
        DEPENDS ${XDG_SHELL_XML})
    target_sources(luna-compositor-qt PRIVATE ${XDG_SHELL_C})

    qt_add_qml_module(luna-compositor-qt
        URI Luna.Compositor
        VERSION 1.0
        QML_FILES
            qml/Main.qml
            qml/Bar.qml
            qml/ClientWindow.qml
            qml/LayerSurfaceItem.qml
            qml/Layout.js
    )

    target_include_directories(luna-compositor-qt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

    target_link_libraries(luna-compositor-qt PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::WaylandCompositor
        Qt6::WaylandCompositorPrivate
        PkgConfig::WAYLAND_SERVER
    )
endif()

# ---------------------------------------------------------------------------
# luna-compositor: the product base, on our waylib fork (wlroots underneath).
# ---------------------------------------------------------------------------
if(LUNA_BUILD_WAYLIB)
    find_package(WaylibServer REQUIRED)
    find_package(Qt6 REQUIRED COMPONENTS QuickPrivate)
    pkg_check_modules(PIXMAN REQUIRED IMPORTED_TARGET pixman-1)

    # All QML files sit at the module root, so relative imports work.
    foreach(_qml Scene.qml OutputDelegate.qml ClientWindow.qml LayerItem.qml Bar.qml Layers.js)
        set_source_files_properties(luna/qml/${_qml} PROPERTIES QT_RESOURCE_ALIAS ${_qml})
    endforeach()

    qt_add_executable(luna-compositor
        luna/src/main.cpp
        luna/src/server.h
        luna/src/server.cpp
        luna/src/output_capture.h
        luna/src/output_capture.cpp
        src/frame_log.cpp
        src/frame_log.h
    )

    qt_add_qml_module(luna-compositor
        URI Luna.Server
        VERSION 1.0
        IMPORTS Waylib.Server
        QML_FILES
            luna/qml/Scene.qml
            luna/qml/OutputDelegate.qml
            luna/qml/ClientWindow.qml
            luna/qml/LayerItem.qml
            luna/qml/Bar.qml
            luna/qml/Layers.js
            qml/Layout.js
    )

    target_include_directories(luna-compositor PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/luna/src ${CMAKE_CURRENT_SOURCE_DIR}/src)
    # wlroots headers need this; C++ keywords in them are hidden by wlr_all.h.
    target_compile_definitions(luna-compositor PRIVATE WLR_USE_UNSTABLE)

    target_link_libraries(luna-compositor PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickPrivate
        Waylib::WaylibServer
        PkgConfig::PIXMAN
        PkgConfig::WAYLAND_SERVER
    )

    # Find the fork's libraries at run time without LD_LIBRARY_PATH.
    set_target_properties(luna-compositor PROPERTIES
        BUILD_RPATH "${LUNA_VENDOR_PREFIX}/lib")
endif()
