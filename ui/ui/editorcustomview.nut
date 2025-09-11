import "%ui/components/icon3d.nut" as iconWidget

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

function mkIconView(eid){
  if (ecs.obsolete_dbg_get_comp_val(eid, "animchar__res") != null && ecs.obsolete_dbg_get_comp_val(eid, "item__iconYaw") != null) { 
    let itemParams = Watched(null)
    let iconParams = {width=min(hdpx(256), fsh(40)), height=min(hdpx(256), fsh(40))}
    function updateItemParams(){
      let iconOffs = ecs.obsolete_dbg_get_comp_val(eid, "item__iconOffset")
      let itemTbl = {
        iconName = ecs.obsolete_dbg_get_comp_val(eid, "animchar__res")
        iconYaw = ecs.obsolete_dbg_get_comp_val(eid, "item__iconYaw")
        iconPitch = ecs.obsolete_dbg_get_comp_val(eid, "item__iconPitch")
        iconRoll = ecs.obsolete_dbg_get_comp_val(eid, "item__iconRoll")
        iconScale = ecs.obsolete_dbg_get_comp_val(eid, "item__iconScale")
        iconSunZenith = ecs.obsolete_dbg_get_comp_val(eid, "item__iconSunZenith")
        iconSunAzimuth = ecs.obsolete_dbg_get_comp_val(eid, "item__iconSunAzimuth")
        iconRecalcAnimation = ecs.obsolete_dbg_get_comp_val(eid, "item__iconRecalcAnimation")
        iconOffsX = iconOffs?.x
        iconOffsY = iconOffs?.y
      }
      itemParams.set(itemTbl)
    }
    updateItemParams()
    let uniqueTimerKey = $"editorCustomView, mkIconView, {eid}, {ecs.obsolete_dbg_get_comp_val(eid, "animchar__res")}"
    gui_scene.clearTimer(uniqueTimerKey)
    gui_scene.setInterval(1, updateItemParams, uniqueTimerKey)
    return @(){
      watch = itemParams
      children = iconWidget(itemParams.get(), iconParams)
      hplace = ALIGN_CENTER
      onDetach = @() gui_scene.clearTimer(uniqueTimerKey)
    }
  }
  return null
}
return mkIconView
