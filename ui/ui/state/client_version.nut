from "%sqGlob/appInfo.nut" import yup_version, exe_version
from "app" import get_circuit
from "vromfs" import get_updated_game_version, get_vromfs_dump_version
from "dagor.fs" import file_exists
from "%ui/state/appState.nut" import isInBattleState
from "%ui/ui_library.nut" import *
from "math" import max
from "%sqstd/version.nut" import Version

let updatedGameVersion = Watched(0)
let mainVromfsVersion = Watched(0)

function updateVromsVersion(inBattle){
  if (inBattle)
    return
  let isMoonCircuit = ["am-test"].contains(get_circuit())
  updatedGameVersion.set(isMoonCircuit ? 0 : get_updated_game_version())
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
