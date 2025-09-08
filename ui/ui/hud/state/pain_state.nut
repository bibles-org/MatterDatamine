import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let hasPainEffect = Watched(false)

ecs.register_es("pain_state_ui_es", {
  [["onInit", "onChange"]] = @(_, comp) hasPainEffect.set(comp.pain__active),
  onDestroy = @(_, _comp) hasPainEffect.set(false)

},{
  comps_rq = [["watchedByPlr"]],
  comps_track = [["pain__active", ecs.TYPE_BOOL]]
})


return hasPainEffect
