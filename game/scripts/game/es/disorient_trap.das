require ecs
require ecs.common
require game.events.events
require DagorConsole
require app
require math
require math.base
require game.es.confusion_common
require game.es.concussion_common
require game.events.events_game
require game.events.events_active_matter


[es(tag=server, no_order)]
def disorient_trap_carrier_restore_spores(act : ParallelUpdateFrameDelayed;
                                          disorient_trap_carrier__maxSporeCount : float;
                                          disorient_trap_carrier__trapCost : float;
                                          disorient_trap_carrier__sporeRestoreSpd : float;
                                          var zone__active : bool&;
                                          var disorient_trap_carrier__curSporeCount : float&)
  disorient_trap_carrier__curSporeCount += disorient_trap_carrier__sporeRestoreSpd * act.dt
  zone__active = disorient_trap_carrier__curSporeCount >= disorient_trap_carrier__trapCost
  if disorient_trap_carrier__curSporeCount > disorient_trap_carrier__maxSporeCount
    disorient_trap_carrier__curSporeCount = disorient_trap_carrier__maxSporeCount


[es(tag=server)]
def disorient_trap_carrier_zone_enter(evt : EventZoneEnter;
                                      disorient_trap_carrier__trapCost : float;
                                      var disorient_trap_carrier__curSporeCount : float&)
  if (evt.visitorEid |> get_Eid("possessedByPlr") ?? INVALID_ENTITY_ID) == INVALID_ENTITY_ID
    return
  if disorient_trap_carrier__curSporeCount < disorient_trap_carrier__trapCost
    return

  query(evt.visitorEid) <| $ [es] (transform : float3x4)
    disorient_trap_carrier__curSporeCount -= disorient_trap_carrier__trapCost
    createEntity("disorient_trap_cloud") <| $(var init : ComponentsInitializer)
      var tm = transform
      tm[3] = tm[3] + float3(0.0, 1.5, 0.0)
      init |> set("transform", tm)

[es(tag=server, REQUIRE=disorient_trap_cloud)]
def disorient_zone_enter(evt : EventZoneEnter; disorient_trap__effectTemplate : string)
  if (evt.visitorEid |> get_Eid("possessedByPlr") ?? INVALID_ENTITY_ID) == INVALID_ENTITY_ID
    return
  var isAlredyPoisoned = false
  query(evt.visitorEid) <| $ [es] (var disorient_poison__isAccumulated : bool&)
    disorient_poison__isAccumulated = true
    isAlredyPoisoned = true
  if !isAlredyPoisoned
    addSubTemplate(evt.visitorEid, disorient_trap__effectTemplate)


[es(tag=server, REQUIRE=disorient_trap_cloud)]
def disorient_zone_leave(evt : EventZoneLeave)
  query(evt.visitorEid) <| $ [es] (var disorient_poison__isAccumulated : bool&)
    disorient_poison__isAccumulated = false


[es(tag=server, no_order)]
def spore_poison_status_update(act : ParallelUpdateFrameDelayed;
                               eid : EntityId;
                               disorient_poison__isAccumulated : bool;
                               disorient_poison__maxValue : float;
                               disorient_poison__accumulateSpd : float;
                               disorient_poison__effectRefreshRateRange : float2;
                               disorient_poison__confusionRange : float2;
                               var disorient_poison__curValue : float&;
                               var disorient_poison__effectNextRefresh : float&)
  let delta = act.dt * disorient_poison__accumulateSpd * (disorient_poison__isAccumulated ? 1.0 : -1.0)
  disorient_poison__curValue = clamp(disorient_poison__curValue + delta, 0.0, disorient_poison__maxValue)
  if disorient_poison__curValue == 0.0
    removeSubTemplate(eid, "disorient_spore_poisoned_effect")
    return

  if act.curTime > disorient_poison__effectNextRefresh
    let t = disorient_poison__curValue / disorient_poison__maxValue
    let refreshRate = lerp(disorient_poison__effectRefreshRateRange.x, disorient_poison__effectRefreshRateRange.y, t)
    let confusionPower = lerp(disorient_poison__confusionRange.x, disorient_poison__confusionRange.y, t)
    disorient_poison__effectNextRefresh = act.curTime + refreshRate
    enable_confusion_affect(eid, 0.9 * refreshRate, confusionPower) //0.9 to remove prevoius effect earlier
    enable_concussion_affect(eid, "disorient_spore_concussion_affect")
