#pragma once

// wlroots headers that waylib's wlr_all.h does not include.
#include <wlr_all.h>

#define static
extern "C" {
#include <wlr/types/wlr_content_type_v1.h>
#include <wlr/types/wlr_presentation_time.h>
#include <wlr/types/wlr_tearing_control_v1.h>
#include <wlr/types/wlr_virtual_pointer_v1.h>
#include <wlr/types/wlr_xdg_activation_v1.h>
#include <wlr/types/wlr_xdg_foreign_registry.h>
#include <wlr/types/wlr_xdg_system_bell_v1.h>
#include <wlr/types/wlr_xdg_toplevel_icon_v1.h>
}
#undef static
