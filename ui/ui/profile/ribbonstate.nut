from "%ui/profile/profileState.nut" import teamColorIdxsUpdate

let { settings, onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")
let { teamColorIdxs } = require("%ui/profile/profileState.nut")

function saveRibbons() {
  if (!onlineSettingUpdated.get())
    return
  settings.mutate(@(v) v["last_ribbons"] <- teamColorIdxs.get())
}

let loadRibbons = @() teamColorIdxsUpdate(settings.get()?["last_ribbons"] ?? {primary=-1, secondary=-1})

onlineSettingUpdated.subscribe_with_nasty_disregard_of_frp_update(@(v) v ? loadRibbons() : null)

return {
  saveRibbons
}
