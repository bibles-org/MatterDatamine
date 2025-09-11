from "%ui/equipPresets/presetsState.nut" import MAX_PRESETS_COUNT, PRESET_VERSION
from "%sqstd/json.nut" import loadJson, saveJson

from "%ui/ui_library.nut" import *

let { onlineSettingUpdated, settings } = require("%ui/options/onlineSettings.nut")
let { PLAYER_PRESETS_IN_ONLINE_SETTINGS, LAST_USED_EQUIPMENT, PRESET_PREFIX, PRESET_VERSION_KEY } = require("%ui/equipPresets/presetsState.nut")
let { logerr } = require("dagor.debug")
let defaultPresets = require("%ui/equipPresets/defaultPlayerPresets.nut")

let presetsToSave = {}

#allow-auto-freeze

let localPresetsFileName = "_playerPresetData.json"

console_register_command(function() {
  settings.mutate(function(v) {
    v[PLAYER_PRESETS_IN_ONLINE_SETTINGS] <- null
    v[PRESET_VERSION_KEY] <- null
  })
}, "playerPresets.clearOnlineSettingsData")

onlineSettingUpdated.subscribe_with_nasty_disregard_of_frp_update(function(updated) {
  if (!updated)
    return

  let currentPresetVersion = settings.get()?[PRESET_VERSION_KEY]
  if (currentPresetVersion == PRESET_VERSION)
    return

  
  settings.mutate(function(onlineSettings) {
    print($"[Player presets] preset has version {currentPresetVersion}. Current version: {PRESET_VERSION}. Patching...")
    let presets = onlineSettings?[PLAYER_PRESETS_IN_ONLINE_SETTINGS] ?? {}

    for (local i = 0; i < MAX_PRESETS_COUNT; i++) {
      let presetname = $"{PRESET_PREFIX}_{i}"
      presets[presetname] <- defaultPresets?[$"{PRESET_PREFIX}_{i}"]
    }

    let lastUsedKey = $"{PRESET_PREFIX}_{LAST_USED_EQUIPMENT}"
    let lastUsedPreset = presets?[lastUsedKey]
    if (lastUsedPreset!=null) {
      presets[lastUsedKey] <- null
    }

    onlineSettings[PLAYER_PRESETS_IN_ONLINE_SETTINGS] <- presets
    onlineSettings[PRESET_VERSION_KEY] <- PRESET_VERSION
  })
})

function savePlayerPresetsToLocal() {
  let currentPresets = settings.get()?[PLAYER_PRESETS_IN_ONLINE_SETTINGS] ?? {}

  for (local i = 0; i < MAX_PRESETS_COUNT; i++) {
    let presetKey = $"{PRESET_PREFIX}_{i}"
    let p = clone(currentPresets?[presetKey])
    presetsToSave[presetKey] <- p
  }

  saveJson(localPresetsFileName, presetsToSave)
}

function loadPlayerPresetsFromLocal() {
  let localData = loadJson(localPresetsFileName) ?? {}
  log($"Loading local data from {localData}")

  if (localData.len() == 0)
    logerr($"Failed to load file from {localPresetsFileName}")

  settings.mutate(function(onlineSettings) {
    let presets = onlineSettings?[PLAYER_PRESETS_IN_ONLINE_SETTINGS] ?? {}

    foreach (presetKey, presetVal in localData) {
      presets[presetKey] <- presetVal
    }
  })
}

console_register_command(savePlayerPresetsToLocal, "playerPresets.saveToLocal")
console_register_command(loadPlayerPresetsFromLocal, "playerPresets.loadFromLocal")

return {
  savePlayerPresetsToLocal
  loadPlayerPresetsFromLocal
}