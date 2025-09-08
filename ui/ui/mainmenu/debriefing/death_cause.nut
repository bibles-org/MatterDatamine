from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { DM_PROJECTILE, DM_COLLISION, DM_ZONE } = require("dm")
let { EventEntityDied } = require("dasevents")
let { get_sync_time } = require("net")
let { getDamageTypeStr } = require("%ui/hud/state/human_damage_model_state.nut")


let deathCause = Watched(null)
let trapRecencyLimit = 2.5


let death_cause_victim_query = ecs.SqQuery("death_cause_victim_query", {
  comps_ro=[
    ["trap_logger__lastTrapActivationTime", ecs.TYPE_FLOAT],
    ["isInVehicle", ecs.TYPE_BOOL]
  ]
})

let wasRecentlyTrapped = @(victim) death_cause_victim_query.perform(victim, @(_, comp) (get_sync_time() - comp.trap_logger__lastTrapActivationTime) < trapRecencyLimit)
let wasInVechicle = @(victim) death_cause_victim_query.perform(victim, @(_, comp) comp.isInVehicle)

let wasKilledByTrap = @(evt) evt.damageType == DM_COLLISION && wasRecentlyTrapped(evt.victim)
let vechicleCrash = @(evt) evt.damageType != DM_PROJECTILE && evt.damageType != DM_ZONE && wasInVechicle(evt.victim)

let updateDeathData = function(evt) {
  if (wasKilledByTrap(evt)) {
    return {
      cause = "deathCause/trap"
    }
  }
  if (vechicleCrash(evt)) {
    return {
      cause = "deathCause/crash"
    }
  }
  return {
    cause = $"deathCause/{getDamageTypeStr(evt.damageType)}"
  }
}

ecs.register_es("death_data_for_local_hero_es", {
  onInit = @(_evt, _eid, _comp) deathCause(null),
  [EventEntityDied] = @(evt, _eid, _comp) deathCause(updateDeathData(evt))
},
{
  comps_rq=["hero"]
})

return {
  deathCause
}