obs = obslua

currentUsedMediaSourceName = ""
manualSelectedMediaSourceName = ""
textSourceName = ""

last_text = ""
DEFAULT_COLOR = 0x11FF21
WARNING_COLOR = 0x00A5FF
CRITICAL_COLOR = 0x0000FF
DEFAULT_WARNING_TIME = 1
DEFAULT_CRITICAL_TIME = 30


color_default = DEFAULT_COLOR
color_warning = WARNING_COLOR
color_critical = CRITICAL_COLOR
time_warning_minutes = DEFAULT_WARNING_TIME
time_critical_seconds = DEFAULT_CRITICAL_TIME

function timer_callback()
    local mediaSource = obs.obs_get_source_by_name(currentUsedMediaSourceName)
    if mediaSource == nil then
        clear_text_source()
        return
    end

    local time = obs.obs_source_media_get_time(mediaSource)
    local duration = obs.obs_source_media_get_duration(mediaSource)
    obs.obs_source_release(mediaSource)

    if duration == 0 then
        clear_text_source()
        return
    end

    local timeLeft = duration - time
    local seconds = string.format("%02d", (math.floor(timeLeft / 1000) % 60))
    local minutes = string.format("%02d", math.floor(timeLeft / 1000 / 60) % 60)
    local hours = math.floor(timeLeft / 1000 / 60 / 60)
    local text = string.format("-%d:%s:%s", hours, minutes, seconds)

    if text == last_text then
        return
    end

    local time_warning = time_warning_minutes * 60000
    local time_critical = time_critical_seconds * 1000


    local color = color_default
    if timeLeft <= time_warning then
        color = color_warning
    end
    if timeLeft <= time_critical then
        color = color_critical
    end

    update_text_source(text, color)
    last_text = text
end

function update_text_source(text, color)
    local source = obs.obs_get_source_by_name(textSourceName)
    if source ~= nil then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_data_set_int(settings, "color", color)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

function clear_text_source()
    update_text_source("", color_default)
end

function media_started()
    obs.timer_add(timer_callback, 1000)
end

function media_ended()
    obs.timer_remove(timer_callback)
    clear_text_source()
end

function source_activated(cd)
    local source = obs.calldata_source(cd, "source")
    if isManualModeActive() and obs.obs_source_get_name(source) ~= manualSelectedMediaSourceName then
        return
    end
    select_source(source)
end

function source_deactivated(cd)
    local source = obs.calldata_source(cd, "source")
    deselect_source(source)
end

function select_source(source)
    if source == nil then
        return
    end

    local sourceId = obs.obs_source_get_id(source)
    if sourceId == 'ffmpeg_source' or sourceId == 'vlc_source' then
        currentUsedMediaSourceName = obs.obs_source_get_name(source)
        local sh = obs.obs_source_get_signal_handler(source)
        obs.signal_handler_connect(sh, "media_started", media_started)
        obs.signal_handler_connect(sh, "media_stopped", media_ended)

        if obs.obs_source_media_get_state(source) == 1 then
            obs.timer_add(timer_callback, 1000)
        end
    end
end

function deselect_source(source)
    if source == nil then
        return
    end

    local sourceId = obs.obs_source_get_id(source)
    if sourceId == 'ffmpeg_source' or sourceId == 'vlc_source' then
        local sh = obs.obs_source_get_signal_handler(source)
        obs.signal_handler_disconnect(sh, "media_started", media_started)
        obs.signal_handler_disconnect(sh, "media_stopped", media_ended)

        if currentUsedMediaSourceName == obs.obs_source_get_name(source) then
            obs.timer_remove(timer_callback)
            currentUsedMediaSourceName = ""
            clear_text_source()
        end
    end
end

function isManualModeActive()
    return manualSelectedMediaSourceName ~= "" and manualSelectedMediaSourceName ~= "---AUTO---"
end

function refresh()
    if currentUsedMediaSourceName ~= "" then
        local source = obs.obs_get_source_by_name(currentUsedMediaSourceName)
        if source ~= nil then
            deselect_source(source)
            obs.obs_source_release(source)
        end
    end

    if isManualModeActive() then
        local source = obs.obs_get_source_by_name(manualSelectedMediaSourceName)
        if source ~= nil then
            select_source(source)
            obs.obs_source_release(source)
        end
        return
    end

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if (source_id == 'ffmpeg_source' or source_id == 'vlc_source') and obs.obs_source_active(source) then
                select_source(source)
                return
            end
        end
        obs.source_list_release(sources)
    end
    clear_text_source()
end

function script_load(settings)
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_activate", source_activated)
    obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
    refresh()
end

function script_unload()
end

function script_description()
    return "Sets a text source to act as a media countdown timer when a media source is active\n\n\n\nMod by BadFox based on the Luuk Verhagen script."
end


function script_properties()
    local props = obs.obs_properties_create()
    local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local mediaSourceList = obs.obs_properties_add_list(props, "mediaSource", "Selected media source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(mediaSourceList, "---AUTO---", "auto")


      obs.obs_properties_add_color(props, "color_default", "Default Color")
      obs.obs_properties_add_color(props, "color_warning", "Warning Color")
      obs.obs_properties_add_color(props, "color_critical", "Critical Color")
  

      obs.obs_properties_add_int(props, "time_warning_minutes", "Warning Time (min)", 0, 10, 1)
      obs.obs_properties_add_int(props, "time_critical_seconds", "Critical Time (sec)", 0, 600, 1)
  
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                obs.obs_property_list_add_string(p, obs.obs_source_get_name(source), obs.obs_source_get_name(source))
            end
            if source_id == 'ffmpeg_source' or source_id == 'vlc_source' then
                obs.obs_property_list_add_string(mediaSourceList, obs.obs_source_get_name(source), obs.obs_source_get_name(source))
            end
        end
        obs.source_list_release(sources)
    end

    return props
end

function script_update(settings)
    textSourceName = obs.obs_data_get_string(settings, "source")
    manualSelectedMediaSourceName = obs.obs_data_get_string(settings, "mediaSource")

    color_default = obs.obs_data_get_int(settings, "color_default")
    if color_default == 0 then color_default = DEFAULT_COLOR end

    color_warning = obs.obs_data_get_int(settings, "color_warning")
    if color_warning == 0 then color_warning = WARNING_COLOR end

    color_critical = obs.obs_data_get_int(settings, "color_critical")
    if color_critical == 0 then color_critical = CRITICAL_COLOR end


    time_warning_minutes = obs.obs_data_get_int(settings, "time_warning_minutes")
    if time_warning_minutes == 0 then time_warning_minutes = DEFAULT_WARNING_TIME end

    time_critical_seconds = obs.obs_data_get_int(settings, "time_critical_seconds")
    if time_critical_seconds == 0 then time_critical_seconds = DEFAULT_CRITICAL_TIME end

    refresh()
end

function script_defaults(settings)
    
    obs.obs_data_set_default_int(settings, "color_default", DEFAULT_COLOR)
    obs.obs_data_set_default_int(settings, "color_warning", WARNING_COLOR)
    obs.obs_data_set_default_int(settings, "color_critical", CRITICAL_COLOR)
    obs.obs_data_set_default_int(settings, "time_warning_minutes", DEFAULT_WARNING_TIME)
    obs.obs_data_set_default_int(settings, "time_critical_seconds", DEFAULT_CRITICAL_TIME)
end
