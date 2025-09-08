let { settings, onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")
let { teamColorIdxs, teamColorIdxsUpdate } = require("%ui/profile/profileState.nut")

function saveRibbons() {
  if (!onlineSettingUpdated.get())
    return
  settings.mutate(@(v) v["last_ribbons"] <- teamColorIdxs.get())
}

teamColorIdxs.subscribe(@(_) saveRibbons())

function loadRibbons() {
  teamColorIdxsUpdate(settings.get()?["last_ribbons"] ?? {primary=-1, secondary=-1})
}

onlineSettingUpdated.subscribe(@(v) v ? loadRibbons() : null)

return {
  saveRibbons,
  loadRibbons
}
