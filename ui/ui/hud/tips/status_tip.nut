import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {tipCmp} = require("tipComponent.nut")

let statusTips = Watched({})

function mkText(tipPrefix, tipText, tipData) {
  let prefix = tipPrefix ? $"{loc(tipPrefix)} " : ""
  let text = tipData != null ? loc(tipText, tipData) : loc(tipText)
  return $"{prefix}{text}"
}

ecs.register_es("track_status_tips_es",
  {
    onInit = @(eid, comp) statusTips.mutate(@(t) t[eid] <- {text = mkText(comp.status_tip__textPrefix, comp.status_tip__text, comp.status_tip__data)})
    onDestroy = @(eid, _comp) statusTips.mutate(@(t) t.$rawdelete(eid))
  },
  {
    comps_ro = [
      ["status_tip__text", ecs.TYPE_STRING],
      ["status_tip__textPrefix", ecs.TYPE_STRING, null],
      ["status_tip__data", ecs.TYPE_OBJECT, null]
    ]
  }
)

return function() {
  return {
    watch = [statusTips]
    size = SIZE_TO_CONTENT
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    zOrder = Layers.MsgBox
    children = statusTips.get().map(@(v) tipCmp({text = loc(v.text), needCharAnimation = false})).values()
  }
}
