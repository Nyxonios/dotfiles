-- Hyprland Lua Config
-- Converted from old hyprland.conf for Hyprland 0.56+
-- See https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "DP-1",
    mode     = "5120x1440@120",
    position = "0x0",
    scale    = 1,
})

-- Fallback for any first monitor
hl.monitor({
    output   = "",
    mode     = "5120x1440@120",
    position = "0x0",
    scale    = 1,
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "ghostty"
local fileManager = "nautilus"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("awww img $HOME/dotfiles/wallpapers/art-mars.png --transition-type none")
    -- Expand HYPRLAND_INSTANCE_SIGNATURE at runtime via a sub-shell
    hl.exec_cmd("sh -c 'tmux setenv -g HYPRLAND_INSTANCE_SIGNATURE \"$HYPRLAND_INSTANCE_SIGNATURE\"'")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "20")
hl.env("XCURSOR_THEME", "breeze")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
-- NVIDIA settings
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in    = 0,
        gaps_out   = 0,
        border_size = 1,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout = "master",
        allow_tearing = false,
    },

    animations = {
        enabled = false,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        orientation                   = "center",
        mfact                         = 0.50,
        slave_count_for_center_master = 0,
    },

    misc = {
        force_default_wallpaper = 0,
    },

    input = {
        kb_layout    = "us,se",
        kb_options   = "grp:caps_switch",
        follow_mouse = 1,
        sensitivity  = 0,
        repeat_rate  = 100,
        repeat_delay = 150,

        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        no_hardware_cursors = true,
        enable_hyprcursor   = false,
    },
})


---------------
---- DEVICE ----
---------------

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + T",     hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",     hl.dsp.window.close()) -- old killactive
hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P",     hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",     hl.dsp.window.pseudo())

-- Floating window preset (toggle + resize + center)
-- Note: Lua resize bindings do not support percentage strings.
-- Using hard-coded pixel values for a 5120x1440 monitor.
-- Adjust x/y if your monitor resolution changes.
hl.bind("SHIFT + ALT + 2", function ()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 2560, y = 1368, relative = false }))
    hl.dispatch(hl.dsp.window.center())
end)

-- Focus
hl.bind(mainMod .. " + f", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Move windows
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Screenshot
hl.bind("SHIFT + CTRL + 4", hl.dsp.exec_cmd("hypershot -m region"))

-- Mouse window operations
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Master layout adjustments
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.layout("mfact +0.02"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.layout("mfact -0.02"))

-- Media keys
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name      = "spotify-to-workspace-7",
    match     = { class = "^(spotify)$" },
    workspace = 7,
})

hl.window_rule({
    name      = "blueman-to-workspace-7",
    match     = { class = "^(.blueman-manager-wrapped)$" },
    workspace = 7,
})

hl.window_rule({
    name      = "mattermost-to-workspace-4",
    match     = { class = "^Mattermost\\.Desktop$" },
    workspace = 4,
})

hl.window_rule({
    name      = "geary-to-workspace-4",
    match     = { class = "^geary$" },
    workspace = 4,
})

hl.window_rule({
    name      = "calendar-to-workspace-4",
    match     = { class = "^org\\.gnome\\.Calendar$" },
    workspace = 4,
})
