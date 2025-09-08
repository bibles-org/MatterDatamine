import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { isDowned } = require("%ui/hud/state/health_state.nut")
let isMachinegunner = require("%ui/hud/state/machinegunner_state.nut")
let {inVehicle} = require("%ui/hud/state/vehicle_state.nut")
let {watchedHeroEid} = require("%ui/hud/state/watched_hero.nut")

let jetfuel = mkWatched(persist, "jetfuel")
let fuelAlert = mkWatched(persist, "jetfuelAlert")
let showTakeoffHint = mkWatched(persist, "takeoffHint", false)
let {curTime} = require("%ui/hud/state/time_state.nut")
const takeoffHintShowTime = 15.0
let lockUse = mkWatched(persist, "lockJetpackUse")
let jetpackFuelsCount = mkWatched(persist, "jetpackFuelsCount")

local takeoffHintStarted = -1.0

let getSpectatorTargetQuery = ecs.SqQuery("getSpectatorTargetQuery", {comps_ro = [["spectator__target", ecs.TYPE_EID], ["camera__active", ecs.TYPE_BOOL]]})
let getSpectatorTarget = @() getSpectatorTargetQuery.perform(function(_, comp) {
  return comp["camera__active"] ? comp["spectator__target"] : ecs.INVALID_ENTITY_ID
})

function trackComponents(_evt,eid,comp) {
  let replayTarget = getSpectatorTarget() ?? ecs.INVALID_ENTITY_ID
  if (eid != controlledHeroEid.value && eid != replayTarget) {
    showTakeoffHint(false)
    jetfuel(-1.0)
    return
  }
  let fuel = comp["human_jetpack__fuel"]
  let maxFuel = comp["human_jetpack__maxFuel"]
  local relativeFuel = maxFuel > 0.0 ? (fuel / maxFuel) * 100.0 : -1.0
  let enabled = comp["human_jetpack__enabled"]
  if (!enabled) {
    relativeFuel = -1.0
    takeoffHintStarted = -1.0
  }
  else if (takeoffHintStarted < 0)
    takeoffHintStarted = curTime.value

  jetfuel.update(relativeFuel)
  fuelAlert.update(comp["human_jetpack__fuelAlert"] && !comp["human_use_object__lockJetpackUse"])
  showTakeoffHint.update(enabled && !comp["human_jetpack__flightMode"] && (fuel > 0 || maxFuel <= 0)
                         && takeoffHintStarted >= 0 && curTime.value - takeoffHintStarted < takeoffHintShowTime)
  lockUse.update(comp["human_use_object__lockJetpackUse"])
  jetpackFuelsCount.update(comp["human_jetpack__inventoryFuelCount"])
}

ecs.register_es("hero_jetfuel_ui_es", {
    [["onChange", "onInit"]]=trackComponents,
    onDestroy = @(_evt, _eid, _comp) jetfuel(-1)
  },
  {
    comps_track = [
      ["human_jetpack__fuel", ecs.TYPE_FLOAT],
      ["human_jetpack__maxFuel", ecs.TYPE_FLOAT],
      ["human_jetpack__enabled", ecs.TYPE_BOOL, false],
      ["human_jetpack__fuelAlert", ecs.TYPE_BOOL, false],
      ["human_jetpack__flightMode", ecs.TYPE_BOOL, false],
      ["human_jetpack__inventoryFuelCount", ecs.TYPE_INT],
      ["human_use_object__lockJetpackUse", ecs.TYPE_BOOL, false],
    ]
    comps_rq = ["watchedByPlr"]
  }
)

let showInBoosters = Watched(true)

function updateShowInBoosters(item_owner, value) {
  if (watchedHeroEid.value == item_owner)
    showInBoosters(value)
}

ecs.register_es("check_show_jetpack_in_boosters_es", {
    [["onInit", "onChange"]] = @(_eid, comp) updateShowInBoosters(comp.item__containerOwnerEid, false)
    onDestroy = @(_eid, comp) updateShowInBoosters(comp.item__containerOwnerEid, true)
  },
  {
    comps_track = [["item__containerOwnerEid", ecs.TYPE_EID]]
    comps_rq = ["dontShowInBoosters"]
  }
)

return {
  jetfuel
  fuelAlert
  showTakeoffHint = Computed(@() showTakeoffHint.value && !isMachinegunner.value && !inVehicle.value && !isDowned.value)
  lockUse
  jetpackFuelsCount
  showInBoosters
}

