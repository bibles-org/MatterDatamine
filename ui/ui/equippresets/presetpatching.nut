from "%ui/ui_library.nut" import *

let { onlineSettingUpdated, settings } = require("%ui/options/onlineSettings.nut")
let { PLAYER_PRESETS_IN_ONLINE_SETTINGS, MAX_PRESETS_COUNT, LAST_USED_EQUIPMENT, PRESET_PREFIX, PRESET_VERSION, PRESET_VERSION_KEY } = require("%ui/equipPresets/presetsState.nut")

onlineSettingUpdated.subscribe(function(updated) {
  if (!updated)
    return

  let currentPresetVersion = settings.get()?[PRESET_VERSION_KEY]
  if (currentPresetVersion == PRESET_VERSION)
    return

  
  settings.mutate(function(onlineSettings) {
    print($"[Player presets] preset has version {currentPresetVersion}. Current version: {PRESET_VERSION}. Patching...")
    let presets = onlineSettings?[PLAYER_PRESETS_IN_ONLINE_SETTINGS] ?? {}

    for (local i = 0; i < MAX_PRESETS_COUNT; i++) {
      let p = presets?[$"{PRESET_PREFIX}_{i}"]

      if (p == null)
        continue

      presets[$"{PRESET_PREFIX}_{i}"] = null
    }

    let lastUsedKey = $"{PRESET_PREFIX}_{LAST_USED_EQUIPMENT}"
    let lastUsedPreset = presets?[lastUsedKey]
    if (lastUsedPreset!=null) {
      presets[lastUsedKey] = null
    }
    onlineSettings[PRESET_VERSION_KEY] <- PRESET_VERSION
  })
})