import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import Watched

let helps = Watched({})

function updateHelp(eid, comp) {
  helps.mutate(function(v) {
    v[eid] <- {
      help__visible = comp["help__visible"]
      text = comp["help__text"]
      title = comp["help__title"]
      width = comp["help__textWidth"]
      maxFullDistance = comp["help__fullDistance"]
      maxShortDistance = comp["help__shortDistance"]
      requireTrace = comp.help__requireTrace
      traceSuccess = comp.help__traceSuccess
      transform = comp.transform
      eid
    }
  })
}

ecs.register_es("help_markers_visible_ui_es",
  {[["onInit", "onChange"]] = function(eid, comp){
      if (comp["help__visible"]) {
        updateHelp(eid, comp)
      }
      else if (eid in helps.value) {
        helps.mutate(@(v) v.$rawdelete(eid))
      }
    },
    function onDestroy(eid, _comp){
      if (eid in helps.value)
        helps.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {
    comps_ro = [
      ["help__text", ecs.TYPE_STRING],
      ["help__title", ecs.TYPE_STRING],
      ["help__visible", ecs.TYPE_BOOL],
      ["help__textWidth", ecs.TYPE_INT],
      ["transform", ecs.TYPE_MATRIX, null],
      ["help__fullDistance", ecs.TYPE_FLOAT],
      ["help__shortDistance", ecs.TYPE_FLOAT],
      ["help__requireTrace", ecs.TYPE_BOOL, false]
    ],
    comps_track = [ ["help__visible", ecs.TYPE_BOOL], ["help__traceSuccess", ecs.TYPE_BOOL, false] ]
  },
  {after="*", before="*"}
)

return {
    help_markers = helps
}
