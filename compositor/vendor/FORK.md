# The waylib fork (luna-compositor base)

Decision: moonshot.md §32 (2026-10-29). luna-compositor runs on our own fork of waylib, carried with our patches.

## What is here

| Folder | Upstream | Pin | Commit | Licence |
|---|---|---|---|---|
| `treeland/` | https://github.com/linuxdeepin/treeland | tag `0.11.0` (2026-10-10, the version Arch packages as `treeland 0.11.0`), our branch `luna` | base `f342a5b6debd028ed9bc4bc3e806118efbcae8f2`, `luna` head `5eff9a273f6f6b8551d0340765dd609f6a935b6c` | waylib and Treeland: `Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only` (SPDX header in every file, `LICENSES/`); vendored wlroots: MIT (`3rdparty/wlroots/LICENSE`) |
| `treeland-protocols/` | https://github.com/linuxdeepin/treeland-protocols | tag `0.8.0` (Arch `treeland-protocols 0.8.0`) | `f6203a9db4cce16226a8bad46f645db0539c9a7d` | protocol XML: MIT (SPDX in each file); build files: GPL-2.0-only and CC0-1.0 (`REUSE.toml`) |
| `wlr-protocols/` | https://gitlab.freedesktop.org/wlroots/wlr-protocols | `a741f0a` (Arch `wlr-protocols r112.a741f0a`) | `a741f0ac5d655338a5100fc34bc8cec87d237346` | per-file permissive licences (MIT and HPND-style notices in each XML) |

Each folder is its own git checkout and stays out of the monorepo (see `../.gitignore`). `fetch.sh` clones each one
at its pinned commit and rebuilds our `luna` branch from `patches/treeland/` (made with `git format-patch 0.11.0..luna`).
When a patch is added on `luna`, export it to `patches/treeland/` and list it below. A public fork remote (and a
submodule) can replace this later without changing the build.

### Where waylib and qwlroots are now

- waylib moved from github.com/vioken/waylib into the Treeland repository as `treeland/waylib/` (version 0.6.13 in
  its CMake project).
- **qwlroots no longer exists at 0.11.0.** Treeland removed it in 2026 (commits `d7ffa9d8` "delete qwlroots layer,
  waylib/treeland use wlroots C API directly" and `9582881d`). waylib now calls the wlroots C API through
  `kernel/wlr_all.h`. There is nothing of qwlroots to fork.
- wlroots is vendored as a non-squash subtree in `treeland/3rdparty/wlroots/` (upstream 0.20.2,
  `d783533489e1f75d6886c2ab5c5960090ef268f8`, see `treeland/wlroots/UPSTREAM`), built by CMake in
  `treeland/wlroots/` as `libwaylib-wlroots.so`.
- The system `wlroots0.20 0.20.2` is **not** used: Treeland patches its copy (an extra `dnd_action` signal in
  `struct wlr_data_source`, Vulkan render-buffer helpers for the Qt RHI bridge), so the struct layout differs and
  the system library would break waylib at run time.

## Build

`vendor/build-waylib.sh` builds only waylib, its vendored wlroots and the two protocol packages. Nothing is built
from the Treeland desktop itself (no dtk, no ddm).

- Build trees: `opal/compositor/vendor-build/`. Install prefix: `opal/compositor/vendor-prefix/`. Both are in
  `.gitignore`. No sudo, nothing under `/usr`.
- All wlroots features are on: DRM, libinput, X11 and Wayland backends, GLES2 and Vulkan renderers, GBM and udmabuf
  allocators, session, Xwayland, colour management (lcms2), libliftoff, xcb-errors.
- Two build dependencies are not installed on this machine and are built into the prefix instead:
  `wlr-protocols` and `treeland-protocols`. The packaged way is `sudo pacman -S wlr-protocols treeland-protocols`;
  it is not needed.
- GCC 16.x crashed with an internal compiler error (segmentation fault) twice in about 1200 compiles (once at
  `-j12`, once at `-j6`), each time in a different file. A retry continues. The script retries up to three times when the log shows the crash.
- `luna-compositor` finds the fork with `CMAKE_PREFIX_PATH=vendor-prefix` and an RPATH to `vendor-prefix/lib`.

## Patch policy

- Our changes are separate, small commits on the `luna` branch of `treeland/`, on top of the upstream tag.
- Each commit changes one thing, says why in its message, and is listed below with a one-line reason.
- Prefer a change in luna-compositor over a change in the fork. Patch the fork only when the fork is wrong or
  closed (private API, missing hook, build break).
- Patches that are useful upstream are offered upstream; the list notes the state.
- To move to a new upstream tag: rebase `luna` on the tag, rebuild with `vendor/build-waylib.sh`, run
  `run-shell.sh` and compare the frame log.

## Patches on `luna`

| Commit | Files | Reason |
|---|---|---|
| `08c02350` build: make the standalone waylib install usable | `waylib/src/server/CMakeLists.txt`, `wlroots/CMakeLists.txt` | With `NAMELINK_ONLY`, CMake 4 installed no exported targets and no public headers, so an installed WaylibServer package was unusable. |
| `5eff9a27` waylib: send presentation-time feedback for rendered surfaces | `waylib/src/server/qtquick/wsurfaceitem.cpp`, `waylib/src/server/kernel/wlr_all.h` | waylib never marked a buffer as sampled, so `wp_presentation` feedback never got `presented`; §6.1 needs it. |

Upstream state: not offered yet.
