from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


let deathCause = Watched(null)

ecs.register_es("death_data_for_local_hero_es", {
  [["onInit", "onChange"]] = function (_evt, _eid, comp) {
    if (comp.death_cause_tracking__cause.len() == 0) {
      deathCause.set(null)
    } else {
      deathCause.set({cause=$"deathCause/{comp.death_cause_tracking__cause}"})
    }
  }
},
{
  comps_rq=["hero"]
  comps_track = [["death_cause_tracking__cause", ecs.TYPE_STRING]]
})

return {
  deathCause
}
