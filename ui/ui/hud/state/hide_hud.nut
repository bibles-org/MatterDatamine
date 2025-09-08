from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")


let hideHud = mkWatched(persist, "hideHud", false)

let isHero = @(eid) eid == controlledHeroEid.get()

ecs.register_es("track_hide_hud_game_effect",
  {
    onInit = @(_evt, comp) isHero(comp.game_effect__attachedTo) ? hideHud.set(true) : null
    onDestroy = @(_evt, comp) (comp.onboarding_effect_guaranteed_destroy != null || isHero(comp.game_effect__attachedTo)) ? hideHud.set(false) : null
  },
  {
    comps_rq = [ "hide_ui_game_effect" ],
    comps_ro = [ ["game_effect__attachedTo", ecs.TYPE_EID], ["onboarding_effect_guaranteed_destroy", ecs.TYPE_TAG, null] ]
  }
)

return hideHud