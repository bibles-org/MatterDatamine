from "%ui/hud/state/cortical_vaults_es.nut" import corticalVaultsGetWatched

from "%ui/ui_library.nut" import *

from "%ui/hud/map/map_assistant_points.nut" import activityPoints
from "%ui/components/colors.nut" import TextNormal

let pointHeight = hdpxi(20)
function mkCompassAssistanPoint(eid, info) {
  return {
    rendObj = ROBJ_IMAGE
    image = Picture($"ui/skin#eye.svg:{pointHeight}:{pointHeight}:P")
    data = { worldPos = info.pos }
    transform = {}
    color = TextNormal
    size = [pointHeight, pointHeight]
    behavior=DngBhv.OpacityByComponent
    opacityComponentEntity = eid
    opacityComponentName = "hud_marker__opacity"
  }
}


let mkAssistantPoints = @(state) {
  watch = state
  function childrenCtor() {
    let res = []
    foreach(eid, info in state.get())
      res.append(mkCompassAssistanPoint(eid, info))

    return res
  }
}



return freeze({
  mkCompassAssistantPoints = @() mkAssistantPoints(activityPoints)
})
