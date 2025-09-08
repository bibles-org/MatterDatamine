from "frp" import Watched, Computed
from "math" import max

let { yup_version, exe_version } = require("%sqGlob/appInfo.nut")
let { get_updated_game_version, get_vromfs_dump_version } = require("vromfs")
let { Version } = require("%sqstd/version.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

let updatedGameVersion = Watched(0)
let mainVromfsVersion = Watched(0)

function updateVromsVersion(inBattle){
  if (inBattle)
    return
  updatedGameVersion(get_updated_game_version())
  mainVromfsVersion(get_vromfs_dump_version("content/active_matter/active_matter-game.vromfs.bin"))
}

isInBattleState.subscribe(updateVromsVersion)
updateVromsVersion(isInBattleState.value)

let maxVersionInt = Computed(@() max(
  (updatedGameVersion.value ?? 0),
  (mainVromfsVersion.value ?? 0),
  Version(exe_version.value ?? 0).toint(),
  Version(yup_version.value ?? 0).toint()
))

let maxVersionStr = Computed(@() Version(maxVersionInt.value).tostring() )

return {
  maxVersionInt
  maxVersionStr
}