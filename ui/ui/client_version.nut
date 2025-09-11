from "vromfs" import get_updated_game_version, get_vromfs_dump_version
from "frp" import Watched, Computed
from "math" import max

let { yup_version, exe_version } = require("%sqGlob/appInfo.nut")
let { Version } = require("%sqstd/version.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

let updatedGameVersion = Watched(0)
let mainVromfsVersion = Watched(0)

function updateVromsVersion(inBattle){
  if (inBattle)
    return
  updatedGameVersion.set(get_updated_game_version())
  mainVromfsVersion.set(get_vromfs_dump_version("content/active_matter/active_matter-game.vromfs.bin"))
}

isInBattleState.subscribe_with_nasty_disregard_of_frp_update(updateVromsVersion)
updateVromsVersion(isInBattleState.get())

let maxVersionInt = Computed(@() max(
  (updatedGameVersion.get() ?? 0),
  (mainVromfsVersion.get() ?? 0),
  Version(exe_version.get() ?? 0).toint(),
  Version(yup_version.get() ?? 0).toint()
))

let maxVersionStr = Computed(@() Version(maxVersionInt.get()).tostring() )

return {
  maxVersionInt
  maxVersionStr
}