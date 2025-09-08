import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let downedEndTime = Watched(-1.0)

ecs.register_es("downedTracker",{
  [["onInit", "onChange"]] = @(_eid, comp) downedEndTime.set(comp.hitpoints__downedEndTime)
  onDestroy = @(_eid, _comp) downedEndTime.set(-1.0)
},
{
  comps_track = [["hitpoints__downedEndTime",ecs.TYPE_FLOAT, -1]],
  comps_rq=["watchedByPlr","isDowned"]
})

return {
  downedEndTime
}

