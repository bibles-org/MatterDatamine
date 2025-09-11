from "%sqGlob/dasenums.nut" import HumanUseObjectHintType

from "dagor.math" import TMatrix, Point3
from "dasevents" import EventActionMarkerStateChanged

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *



let useObjectHintMarkers = Watched({})
let interactionMenuState = Watched()

ecs.register_es("track_ui_visible_use_object_es",
  {
    [["onInit", "onChange", EventActionMarkerStateChanged]] = function(_evt, eid, comp){
      if (!comp.item_world_marker__enabled || comp.item__useActionHintType != HumanUseObjectHintType.WORLD_MARKER)
        return
      if (comp.item__lootType != "" && comp.item__lootType != "coin")
        return
      local tm = TMatrix(comp.transform)
      tm[3] = Point3(0.0, 0.0, 0.0)
      let pos = comp.transform[3] + tm * comp.item_world_marker__offset
      useObjectHintMarkers.mutate(@(v) v[eid] <- pos)
    }
    onDestroy = @(_evt, eid, _comp) useObjectHintMarkers.mutate(@(v) v.$rawdelete(eid))
  },
  {
    comps_track = [["transform", ecs.TYPE_MATRIX]]
    comps_ro = [
      ["item__useActionHintType", ecs.TYPE_INT, HumanUseObjectHintType.DEFAULT],
      ["item__lootType", ecs.TYPE_STRING, ""],
      ["item_world_marker__enabled", ecs.TYPE_BOOL, true],
      ["item_world_marker__offset", ecs.TYPE_POINT3, Point3(0,0,0)],
    ]
    comps_rq = ["ui_visible"]
    comps_no = ["item_world_marker__pos"]
  }
)

ecs.register_es("interaction_menu",
  {
    onInit = @(_evt, eid, comp) interactionMenuState.set({menu_header = comp.interaction_menu_header.getAll(), menu = comp.interaction_menu.getAll(), eid}),
    onDestroy = @(...) interactionMenuState.set(null)
  },
  {
    comps_rq = ["ui_visible"]
    comps_ro = [
      ["interaction_menu", ecs.TYPE_ARRAY],
      ["interaction_menu_header", ecs.TYPE_ARRAY]
    ]
  }
)

ecs.register_es("track_pos_ui_visible_use_object_es",
  {
    [["onInit", "onChange"]] = function(_evt, eid, comp){
      if (!comp.item_world_marker__enabled || comp.item__useActionHintType != HumanUseObjectHintType.WORLD_MARKER)
        return
      if (comp.item__lootType != "" && comp.item__lootType != "coin")
        return
      local tm = TMatrix(comp.transform)
      tm[3] = Point3(0.0, 0.0, 0.0)
      let pos = comp.item_world_marker__pos + tm * comp.item_world_marker__offset
      useObjectHintMarkers.mutate(@(v) v[eid] <- pos)
    }
    onDestroy = @(_evt, eid, _comp) useObjectHintMarkers.mutate(@(v) v.$rawdelete(eid))
  },
  {
    comps_track = [["item_world_marker__pos", ecs.TYPE_POINT3]]
    comps_ro = [
      ["item__useActionHintType", ecs.TYPE_INT, HumanUseObjectHintType.DEFAULT],
      ["item__lootType", ecs.TYPE_STRING, ""],
      ["item_world_marker__enabled", ecs.TYPE_BOOL, true],
      ["item_world_marker__offset", ecs.TYPE_POINT3, Point3(0,0,0)],
      ["transform", ecs.TYPE_MATRIX],
    ]
    comps_rq = ["ui_visible"]
  }
)

return{
  useObjectHintMarkers
  interactionMenuState
}