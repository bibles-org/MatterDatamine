from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *



let tipInfo = Watched(null)

ecs.register_es("track_game_trigger_screen_hint",
  {
    [["onInit", "onChange"]] = function(_evt, eid, comp) {
      let info = tipInfo.get()
      if (info != null && info.eid != eid) {
        return
      }

      tipInfo.set(comp.game_trigger_processor_show_hint__show ? {
        text = comp.game_trigger_processor_show_hint__text,
        inputId = comp.game_trigger_processor_show_hint__inputId,
        eid
      } : null)
    }

    onDestroy = function(_evt, eid, _comp) {
      let info = tipInfo.get()
      if (info == null || info.eid != eid) {
        return
      }
      tipInfo.set(null)
    }
  }
  { comps_rq = ["game_trigger_processor_show_screen_hint"],
    comps_track = [["game_trigger_processor_show_hint__show", ecs.TYPE_BOOL]],
    comps_ro = [
      ["game_trigger_processor_show_hint__text", ecs.TYPE_STRING],
      ["game_trigger_processor_show_hint__inputId", ecs.TYPE_STRING]
    ]
  },
  { tags = "gameClient" }
)

return @() {
  watch = tipInfo
  size = SIZE_TO_CONTENT
  children = tipInfo.get() == null ? [] : tipCmp({
    inputId = tipInfo.get().inputId
    text = loc(tipInfo.get().text)
  })
}
