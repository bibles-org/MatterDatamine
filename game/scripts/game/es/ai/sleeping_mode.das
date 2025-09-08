require app
require ecs
require DagorRandom
require game.events.events_game
require Grid
require DagorMath
require DngNet
require math.base
require math.random
require walkerai
require game.utils.team
require game.events.inventory_events
require game.events.events_active_matter


[es(tag=server, no_order)]
def update_sleeping_mode(act : UpdateStageInfoAct;
                         sleep_mode__updateInterval : float2;
                         sleep_mode__triggerPoint : float3; sleep_mode__triggerCheckDistSq : float;
                         transform : float3x4;
                         sleep_mode__isSleeping : bool&; var sleep_mode__nextUpdateAt : float&;
                         var sleep_mode__triggered : bool&)
  if act.curTime < sleep_mode__nextUpdateAt
    return
  if sleep_mode__triggered
    sleep_mode__triggered = (!sleep_mode__isSleeping &&
                             distance_sq(transform[3], sleep_mode__triggerPoint) > sleep_mode__triggerCheckDistSq)

  sleep_mode__nextUpdateAt = act.curTime + rnd_float(sleep_mode__updateInterval)


[es(tag=server, no_order)]
def update_sleeping_mode_trigger(act : UpdateStageInfoAct;
                                 sleep_mode__triggerPoint : float3;
                                 sleep_mode__triggerCheckDistSq : float;
                                 transform : float3x4;
                                 sleep_mode__isSleeping : bool;
                                 var sleep_mode__triggered : bool&)
  if !sleep_mode__triggered
    return
  sleep_mode__triggered = (!sleep_mode__isSleeping &&
                           distance_sq(transform[3], sleep_mode__triggerPoint) > sleep_mode__triggerCheckDistSq)


[es(tag=server, after=(ai_target_es, ai_target_transform_es), before=(ai_danger_update_alertness, ai_danger_trace_targets))]
def update_hidden_state_while_sleep(evt : UpdateStageInfoAct;
                                    navmesh_phys__currentWalkVelocity : float3;
                                    walker_agent__targetEid : EntityId;
                                    sleep_mode__isSleeping : bool;
                                    var ai_target : Target)
  ai_target.isHidden = sleep_mode__isSleeping || (length(navmesh_phys__currentWalkVelocity) < 0.001 && !walker_agent__targetEid)


def wakeup_all(pos : float3;
               radius : float;
               trigger_point : float3;
               advance_update_time : float;
               awake_units : int;
               wakeup_causer : EntityId = INVALID_ENTITY_ID)
  var list_to_wakeup : array<tuple< eid : EntityId; distSq : float>>
  let sphere = BSphere3(pos, radius)
  let curTime = get_sync_time()
  var alreadyWakeup = 0
  for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(eid : EntityId; posHuman : float3)
    query(eid) <| $ [es] (sleep_mode__isSleeping : bool; var sleep_mode__nextUpdateAt : float&;
                          var sleep_mode__triggered : bool&; var sleep_mode__triggerPoint : float3&)
      if !sleep_mode__isSleeping
        alreadyWakeup += 1
        sleep_mode__nextUpdateAt = max(sleep_mode__nextUpdateAt, curTime + advance_update_time)
        sleep_mode__triggered = true
        sleep_mode__triggerPoint = trigger_point
      else
        list_to_wakeup |> push((eid, distance_sq(posHuman, pos) * gfrnd()))

  let baseQuantityUnits = awake_units
  let quantityWakeupUnits = max(min(baseQuantityUnits - alreadyWakeup, length(list_to_wakeup)), 0)
  if quantityWakeupUnits == 0
    return
  sort(list_to_wakeup) <| $(lhs, rhs)
    return lhs.distSq < rhs.distSq
  for i in range(quantityWakeupUnits)
    query(list_to_wakeup[i].eid) <| $ [es(REQUIRE_NOT=sleep_mode_wakeup_forbidden)] (team aka sleeper_team : int;
                                                                                     var sleep_mode__isSleeping : bool&;
                                                                                     var sleep_mode__nextUpdateAt : float&;
                                                                                     var sleep_mode__triggered : bool&;
                                                                                     var sleep_mode__triggerPoint : float3&;
                                                                                     var personal_enemies__enemies : EidList?)
      sleep_mode__isSleeping = false
      sleep_mode__nextUpdateAt = max(sleep_mode__nextUpdateAt, curTime + advance_update_time)
      sleep_mode__triggered = true
      sleep_mode__triggerPoint = trigger_point

      if personal_enemies__enemies != null
        query(wakeup_causer) <| $ [es] (team aka wakeup_causer_team : int)
          if is_teams_friendly(sleeper_team, wakeup_causer_team)
            add_personal_enemy(*personal_enemies__enemies, wakeup_causer)


[es(tag=server, on_appear)]
def wakeup_all_around_appear(evt : Event; transform : float3x4; wakeup__radius, wakeup__nextUpdateSleepModeAdd : float;
                             wakeup__awakeUnitsAround : int;
                             trigger_activator : EntityId const?)
  wakeup_all(transform[3], wakeup__radius, transform[3], wakeup__nextUpdateSleepModeAdd, wakeup__awakeUnitsAround,
             trigger_activator ?? INVALID_ENTITY_ID)


[es(tag=server)]
def wakeup_on_am_pickup(evt : EventAmLooted; possessed : EntityId)
  query(possessed) <| $ [es] (transform : float3x4;
                              awake_sleepers_on_am_pickup__radius : float;
                              awake_sleepers_on_am_pickup__awakeUnitsAround : int;
                              awake_sleepers_on_am_pickup__nextUpdateSleepModeAdd : float)
    wakeup_all(transform[3], awake_sleepers_on_am_pickup__radius, transform[3],
               awake_sleepers_on_am_pickup__nextUpdateSleepModeAdd, awake_sleepers_on_am_pickup__awakeUnitsAround)


[es(tag=server)]
def wakeup_on_shell_explosion(evt : EventShellExplodedServer; eid aka shell_eid : EntityId)
  query(shell_eid) <| $ [es] (loud_noise__radius : float; shell_wakeup__nextUpdateSleepModeAdd = 5.0; shell_wakeup__maxUnitsWakeup = 10)
    wakeup_all(evt.pos, loud_noise__radius, evt.pos, shell_wakeup__nextUpdateSleepModeAdd, shell_wakeup__maxUnitsWakeup)


[es(tag=server, no_order, REQUIRE=personalAttractPoint)]
def attraction_point_wakeup_around(info : UpdateStageInfoAct;
                                   eid : EntityId;
                                   item__containerOwnerEid : EntityId;
                                   folower_attraction_point__templateForRemove : string;
                                   var folower_attraction_point__endTimeAt : float&;
                                   var folower_attraction_point__nextTickAt : float&;
                                   folower_attraction_point__wakeupNextUpdateSleepModeAdd : float;
                                   folower_attraction_point__radiusAttraction : float;
                                   folower_attraction_point__checkSleepSleepModeAdd : float;
                                   folower_attraction_point__awakeUnitsAround : int)
  if info.curTime > folower_attraction_point__endTimeAt
    folower_attraction_point__endTimeAt = 0.
    removeSubTemplate(eid, folower_attraction_point__templateForRemove)
  elif info.curTime > folower_attraction_point__nextTickAt
    folower_attraction_point__nextTickAt = info.curTime + folower_attraction_point__wakeupNextUpdateSleepModeAdd
    query(item__containerOwnerEid) <| $ [es] (human__aimTm : float3x4)
      wakeup_all(human__aimTm[3], folower_attraction_point__radiusAttraction, human__aimTm[3],
                 folower_attraction_point__checkSleepSleepModeAdd, folower_attraction_point__awakeUnitsAround)


[es(tag=server, no_order, REQUIRE=itemExtracting)]
def wakeup_all_around_extrating_item(info : UpdateStageInfoAct;
                                     transform : float3x4;
                                     artifact__wakeupRadius : float2;
                                     artifact__wakeupNextUpdateSleepModeAdd : float;
                                     artifact__extractionTime : float;
                                     artifact__extractionTimeAt : float;
                                     artifact__awakeUnitsAround : int)
  let extractionProgress = clamp((info.curTime - artifact__extractionTimeAt + artifact__extractionTime) / artifact__extractionTime, 0., 1.f)
  let radius = cvt(extractionProgress, 0., 1., artifact__wakeupRadius.x, artifact__wakeupRadius.y)
  wakeup_all(transform[3], radius, transform[3], artifact__wakeupNextUpdateSleepModeAdd, artifact__awakeUnitsAround)


[es(tag=server)]
def wakeup_all_around_on_hit(evt : EventOnEntityHit)
  query(evt.victim) <| $ [es] (hit_wakeup__radius, hit_wakeup__nextUpdateSleepModeAdd : float;
                               hit_wakeup__awakeUnitsAround : int;
                               transform aka victim_transform : float3x4)
    var triggerPoint = victim_transform[3]
    query(evt.offender) <| $ [es] (transform aka offender_transform : float3x4)
      triggerPoint = offender_transform[3]

    wakeup_all(victim_transform[3], hit_wakeup__radius, triggerPoint, hit_wakeup__nextUpdateSleepModeAdd, hit_wakeup__awakeUnitsAround)


[es(tag=server, track=sleep_mode__isSleeping, on_appear)]
def sleep_mode_track_additional_templates_server(evt : Event;
                                                 eid : EntityId;
                                                 sleep_mode__isSleeping : bool;
                                                 sleep_mode__awakeTemplateServer : string;
                                                 sleep_mode__sleepTemplateServer : string)
  if sleep_mode__isSleeping
    removeSubTemplate(eid, sleep_mode__awakeTemplateServer)
    addSubTemplate(eid, sleep_mode__sleepTemplateServer)
  else
    removeSubTemplate(eid, sleep_mode__sleepTemplateServer)
    addSubTemplate(eid, sleep_mode__awakeTemplateServer)


[es(tag=gameClient, track=sleep_mode__isSleeping, on_appear)]
def sleep_mode_track_additional_templates_client(evt : Event;
                                                 eid : EntityId;
                                                 attaches_list : EidList;
                                                 sleep_mode__isSleeping : bool;
                                                 sleep_mode__attachesSleepTemplateClient : string;
                                                 sleep_mode__awakeTemplateClient : string;
                                                 sleep_mode__sleepTemplateClient : string)
  if sleep_mode__isSleeping
    removeSubTemplate(eid, sleep_mode__awakeTemplateClient)
    addSubTemplate(eid, sleep_mode__sleepTemplateClient)
    for attach in attaches_list
      addSubTemplate(attach, sleep_mode__attachesSleepTemplateClient)
  else
    removeSubTemplate(eid, sleep_mode__sleepTemplateClient)
    addSubTemplate(eid, sleep_mode__awakeTemplateClient)
    for attach in attaches_list
      removeSubTemplate(attach, sleep_mode__attachesSleepTemplateClient)


[es(tag=server, track=sleep_mode__isSleeping)]
def sleep_mode_track_sleeping(evt : Event; sleep_mode__isSleeping : bool;
                              var agent_dangers__nextDangersTraceTime : float&;
                              var agent_dangers__nextDangersCheckTime : float&)
  if sleep_mode__isSleeping
    return
  agent_dangers__nextDangersTraceTime = 0.0
  agent_dangers__nextDangersCheckTime = 0.0


[es(tag=server, on_appear)]
def sleep_mode_preparing_for_sleep_appear(evt : Event;
                                          eid : EntityId;
                                          sleep_mode_preparing_for_sleep_server_sleepDelay : float;
                                          var sleep_mode_preparing_for_sleep_server_sleepAt : float&)
  sleep_mode_preparing_for_sleep_server_sleepAt = get_sync_time() + sleep_mode_preparing_for_sleep_server_sleepDelay
  send_net_event(eid, EventPreparingToSleep(value = true))


[es(tag=server, on_disappear, REQUIRE=sleep_mode_preparing_for_sleep_server_sleepAt)]
def sleep_mode_preparing_for_sleep_disappear(evt : Event;
                                             eid : EntityId)
  send_net_event(eid, EventPreparingToSleep(value = false))


[es(tag=server, no_order)]
def sleep_mode_preparing_for_sleep_server(act : UpdateStageInfoAct;
                                          eid : EntityId;
                                          sleep_mode_preparing_for_sleep_server_sleepAt : float;
                                          sleep_mode__preparingForSleepTemplateServer : string;
                                          sleep_mode__triggered : bool;
                                          var sleep_mode__isSleeping : bool&)
  if act.curTime < sleep_mode_preparing_for_sleep_server_sleepAt
    if sleep_mode__triggered
      removeSubTemplate(eid, sleep_mode__preparingForSleepTemplateServer)
    return

  removeSubTemplate(eid, sleep_mode__preparingForSleepTemplateServer)
  sleep_mode__isSleeping = true


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def sleep_mode_wakeup_on_death(evt : Event;
                               var sleep_mode__isSleeping : bool&)
  sleep_mode__isSleeping = false


[es(tag=gameClient)]
def sleep_mode_preparing_for_sleep_client(evt : EventPreparingToSleep;
                                          eid : EntityId;
                                          sleep_mode__preparingForSleepTemplateClient : string)
  if evt.value
    addSubTemplate(eid, sleep_mode__preparingForSleepTemplateClient)
  else
    removeSubTemplate(eid, sleep_mode__preparingForSleepTemplateClient)