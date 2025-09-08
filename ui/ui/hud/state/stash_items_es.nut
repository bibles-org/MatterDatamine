import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let stashEid = Watched(0)
let stashItemsMergeEnabled = Watched(true)
let stashItemsSortingEnabled = Watched(true)


ecs.register_es("set_player_stash_inventory_state_ui",
  {
    [["onInit", "onChange"]] = @(_eid, comp) stashEid(comp.player_on_base_components__stashEid)
    onDestroy = function(_eid, _comp){
      stashEid.set(ecs.INVALID_ENTITY_ID)
    }
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["player_on_base_components__stashEid", ecs.TYPE_EID]
    ]
  }
)

ecs.register_es("track_stash_content_ui_es",
  {
    [["onInit", "onChange"]] = function(_evt, eid, comp) {
      if (eid != stashEid.value)
        return
      stashItemsMergeEnabled(comp.itemContainer__uiItemsMergeEnabled)
      stashItemsSortingEnabled(comp.itemContainer__uiItemsSortingEnabled)
    }

  },
  {
    comps_rq = [
      ["inventory__name", ecs.TYPE_STRING]
    ]
    comps_track = [
      ["itemContainer__uiItemsMergeEnabled", ecs.TYPE_BOOL, true],
      ["itemContainer__uiItemsSortingEnabled", ecs.TYPE_BOOL, true]
    ]
  }
)


return {
  stashEid
  stashItemsMergeEnabled
  stashItemsSortingEnabled
}
