import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let isMachinegunner = mkWatched(persist, "isMachinegunner", false)

ecs.register_es("machinegunner_track_es",
  {
    [["onInit","onChange","onDestroy"]] = @(_evt,_eid,comp) isMachinegunner.set(comp["human_attached_gun__isAttached"])
  },
  {comps_track=[["human_attached_gun__isAttached", ecs.TYPE_BOOL]]
   comps_rq = ["hero"]})

return isMachinegunner
