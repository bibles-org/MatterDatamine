from "dasevents" import EventOnPlayerDash
from "net" import get_sync_time

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


const DASH_ABILITY_NAME = "dash"
const SCREAM_ABILITY_NAME = "scream"

let dashAbilitySpawnTime = Watched(0)
let dashAbilitylastFailedUseTime = Watched(0)
let dashAbilityActivationTime = Watched(0)
let dashAbilityDashTime = Watched(0)
let dashAbilityAmCost = Watched(0)
let screamAvailableCount = Watched(null)
let screamMaxCount = Watched(null)

ecs.register_es("dash_ability_state_timings_ui_es", {
  [["onChange", "onInit"]] = function(_eid,comp) {
    dashAbilitySpawnTime.set(comp.hero_dash_ability__spawnTime)
    dashAbilitylastFailedUseTime.set(comp.hero_dash_ability__lastFailedUseTime)
  }

}, {
  comps_track = [
    ["hero_dash_ability__spawnTime", ecs.TYPE_FLOAT],
    ["hero_dash_ability__lastFailedUseTime", ecs.TYPE_FLOAT],
  ]
  comps_rq=["hero"]
})

ecs.register_es("dash_ability_state_cost_ui_es", {
  [["onInit", "onChange"]] = function(_eid, comp) {
    let dashAbility = comp.hero_ability__abilities.getAll().findvalue(@(v) (v?.name ?? "")==DASH_ABILITY_NAME)
    if (dashAbility != null){
      let price = dashAbility?.activeMatterPrice ?? 0
      dashAbilityAmCost.set(price)
    }
  }

}, {
  comps_track = [
    ["hero_ability__abilities", ecs.TYPE_ARRAY],
  ]
  comps_rq=["hero"]
})


ecs.register_es("dash_ability_activate_time_ui_es", {
  [EventOnPlayerDash] = function(_eid,_comp) {
    dashAbilityDashTime.set(get_sync_time())
  }
}, {
  comps_rq=["hero"]
})

ecs.register_es("scream_ability_charges_es", {
  [["onInit","onChange"]] = function(_eid, comp) {
    screamAvailableCount.set(comp.game_effect__screamMinionCount)
    screamMaxCount.set(comp.game_effect__screamMinionCountMax)
  },
  onDestroy = function(_eid, _comp) {
    screamAvailableCount.set(null)
    screamMaxCount.set(null)
  }
}, {
  comps_track = [["game_effect__screamMinionCount", ecs.TYPE_INT, null]],
  comps_ro = [["game_effect__screamMinionCountMax", ecs.TYPE_INT, null]],
  comps_rq = ["watchedByPlr"]
})


return {
  dashAbilitySpawnTime
  dashAbilitylastFailedUseTime
  dashAbilityAmCost
  dashAbilityActivationTime
  dashAbilityDashTime
  DASH_ABILITY_NAME
  screamAvailableCount
  screamMaxCount
  SCREAM_ABILITY_NAME
}
