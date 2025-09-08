import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let isAiming = Watched(false)

ecs.register_es("script_chrosshair_state_es",
  {
    [["onChange","onInit"]] = function(_, _eid, comp){
      isAiming.set(comp["ui_crosshair_state__isAiming"])
    },
    onDestroy = @() isAiming.set(false)
  },
  {
    comps_track = [
      ["ui_crosshair_state__isAiming", ecs.TYPE_BOOL],
    ]
  }
)

return {
  isAiming
}
