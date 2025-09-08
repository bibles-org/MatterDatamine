import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {get_sync_time} = require("net")
let {lerp} = require("%sqstd/math.nut")

let heroAmValue = Watched(0)
let heroAmMaxValue = Watched(100)
local watchedByPlrStoragesGuard = 0

ecs.register_es("track_am_value_ui_es",
  {
    onInit = function(_eid, comp) {
      watchedByPlrStoragesGuard += 1
      heroAmValue.set(comp.am_storage__value)
      heroAmMaxValue.set(comp.am_storage__maxValue)
    }
    onChange = function(_eid, comp) {
      heroAmValue.set(comp.am_storage__value)
      heroAmMaxValue.set(comp.am_storage__maxValue)
    }
    onDestroy = function(_eid, _comp) {
      if (watchedByPlrStoragesGuard > 1) {
        watchedByPlrStoragesGuard -= 1
        return
      }
      else{
        watchedByPlrStoragesGuard = max(0, watchedByPlrStoragesGuard - 1)
        heroAmValue.set(0)
        heroAmMaxValue.set(100)
      }
    }
  },
  {
    comps_track=[["am_storage__value", ecs.TYPE_INT]],
    comps_ro=[["am_storage__maxValue", ecs.TYPE_INT]],
    comps_rq=[["watchedByPlr", ecs.TYPE_EID]]
  }
)

let isSyphoningAm = Watched(false)
let syphoningItem = Watched(ecs.INVALID_ENTITY_ID)
let syphoningTickPeriod = Watched(-1)
let syphoningTickStart = Watched(-1)

ecs.register_es("track_syphoning_am_from_item_ui_es", {
    [["onInit", "onChange"]] = function(_evt, _eid, comp){
      isSyphoningAm.set(comp.am_syphon__extractionSource != ecs.INVALID_ENTITY_ID)
      syphoningItem.set(comp.am_syphon__extractionSource)
      syphoningTickStart.set(get_sync_time())
      syphoningTickPeriod.set(comp.am_syphon__period)
    }
  },
  {
    comps_rq = ["watchedByPlr"]
    comps_ro = [["am_syphon__period", ecs.TYPE_FLOAT]]
    comps_track = [["am_syphon__extractionSource", ecs.TYPE_EID]]
  },
  {tags = "gameClient", after="client_start_player_preparing"}
)

function calcSyphoningProgress(time){
  if (!isSyphoningAm.get())
    return 0
  local res = 0
  let timeFromStart = time - syphoningTickStart.get()
  res = timeFromStart % syphoningTickPeriod.get()
  return lerp(0.0, syphoningTickPeriod.get(), 0.0, 100.0, res)
}

return {
  heroAmValue
  heroAmMaxValue
  isSyphoningAm
  syphoningItem
  calcSyphoningProgress
}