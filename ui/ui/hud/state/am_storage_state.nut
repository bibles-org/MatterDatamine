from "%sqstd/math.nut" import lerp

from "net" import get_sync_time

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let heroAmValue = Watched(0)
let heroAmMaxValue = Watched(100)

ecs.register_es("track_am_value_ui_es",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      heroAmValue.set(comp.am_storage__value)
      heroAmMaxValue.set(comp.am_storage__maxValue)
    }
    onDestroy = function(_eid, _comp) {
      heroAmValue.set(0)
      heroAmMaxValue.set(100)
    }
  },
  {
    comps_track = [["am_storage__value", ecs.TYPE_INT]],
    comps_ro = [["am_storage__maxValue", ecs.TYPE_INT]],
    comps_rq = ["watchedPlayerItem", "item_in_equipment"]
  }
)

return {
  heroAmValue
  heroAmMaxValue
}
