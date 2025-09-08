require app
require ecs
require DngDm
require math.base
require game.es.nexus_common
require game.es.nexus_round_mode_common
require game.events.events
require game.events.events_active_matter



[es(tag=server, REQUIRE=nexus_game_controller)]
def nexus_round_mode_kill_sphere_init(evt : EventNexusRoundModeRoundFinished)
  if evt.reason != int(NexusRoundFinishReason.POINTS)
    return
  var tm = IDENT_TM
  let foundCapturedBeacon = find_query() <| $ [es(REQUIRE=nexus_beacon)] (transform : float3x4;
                                                                          nexus_beacon__controllingTeam : int)
    if nexus_beacon__controllingTeam == evt.winnerTeam
      tm[3] = transform[3]
      return true
    return false
  if !foundCapturedBeacon
    return

  createEntity("nexus_kill_sphere") <| $(var init)
    init |> set("transform", tm)
    init |> set("nexus_kill_sphere__killTeam", get_other_team(evt.winnerTeam))
    init |> set("nexus_kill_sphere__creationTime", get_sync_time())


[es(tag=server, REQUIRE=nexus_kill_sphere)]
def nexus_round_mode_kill_sphere_destory(evt : EventNexusRoundModeRoundChange;
                                         eid : EntityId)
  destroyEntity(eid)


[es(REQUIRE=nexus_kill_sphere, no_order)]
def nexus_kill_sphere_update(act : UpdateStageInfoAct;
                             nexus_kill_sphere__creationTime : float;
                             nexus_kill_sphere__radiusExpansionPerSec : float;
                             var sphere_zone__radius : float&)
  let deltaTime = act.curTime - nexus_kill_sphere__creationTime
  sphere_zone__radius = deltaTime * nexus_kill_sphere__radiusExpansionPerSec


[es(tag=server, REQUIRE=nexus_kill_sphere, after=nexus_kill_sphere_update)]
def nexus_kill_sphere_update_server(act : UpdateStageInfoAct;
                                    transform : float3x4;
                                    nexus_kill_sphere__killTeam : int;
                                    sphere_zone__radius : float)
  let spherePos = transform[3]
  let radiusSq = sphere_zone__radius * sphere_zone__radius

  query() <| $ [es(REQUIRE=nexus_militant)] (eid : EntityId;
                                             team : int;
                                             transform : float3x4)
    if team != nexus_kill_sphere__killTeam
      return
    let humanPos = transform[3]
    let vector = humanPos - spherePos
    let distSq = length_sq(vector)
    if distSq > radiusSq
      return
    sendEvent(eid, CmdKill(damageType = uint16(int(DamageType.DM_ZONE)), deathHpDamage = 100.0))
