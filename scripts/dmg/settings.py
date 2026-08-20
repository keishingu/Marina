from pathlib import Path


app_path = Path(defines["app_path"]).resolve()
background_path = Path(defines["background_path"]).resolve()

files = [str(app_path)]
symlinks = {"Applications": "/Applications"}

format = "UDZO"
filesystem = "HFS+"
background = str(background_path)
icon = str(app_path / "Contents" / "Resources" / "AppIcon.icns")

window_rect = ((200, 120), (660, 400))
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True

icon_size = 128
text_size = 14
label_pos = "bottom"
icon_locations = {
    "Marina.app": (170, 200),
    "Applications": (490, 200),
}
hide_extensions = ["Marina.app"]
