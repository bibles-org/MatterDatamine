import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let isBurning = Watched(false)

ecs.register_es("hero_state_burning_es",
  {
    [["onInit", "onChange"]] = @(_eid, comp) isBurning(comp["burning__isBurning"]),
    onDestroy = @(_eid, _comp) isBurning(false)
  },
  {
    comps_rq = ["watchedByPlr"]
    comps_track = [["burning__isBurning", ecs.TYPE_BOOL]]
  }
)

return {isBurning}