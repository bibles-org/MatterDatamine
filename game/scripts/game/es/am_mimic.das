require ecs
require ecs.common
require app
require net
require strings
require math.base
require math.random
require math.easing
require Dacoll
require DagorMath
require DagorSystem
require DngNet
require pathfinder
require math.maybe_pos
require game.es.grav_zones_common
require game.es.ai.agent_position_mapping_common
require game.es.am_debug_draw_common
require game.es.am_mimic_common
require game.events.events_game
require game.events.events_active_matter


[es(tag=server, on_appear)]
def init_am_mimic_server(evt : Event;
                         am_mimic__radius : float;
                         transform : float3x4;
                         var am_mimic__origin : float3&;
                         var nphys_levitating__elevation : float&;
                         var nphys_levitating__prefferedElevation : float&)
  nphys_levitating__elevation = am_mimic__radius
  nphys_levitating__prefferedElevation = am_mimic__radius
  am_mimic__origin = transform[3]


[es(tag=server, REQUIRE=am_mimic)]
def am_mimic_died_server(evt : EventEntityDied;
                         am_mimic__serverDeathDelay : float;
                         var am_mimic__serverDeathAt : float&)
  am_mimic__serverDeathAt = get_sync_time() + am_mimic__serverDeathDelay


[es(tag=server, REQUIRE=deadEntity, no_order)]
def am_mimic_death_server_es(act : UpdateStageInfoAct;
                             eid : EntityId;
                             am_mimic__serverDeathAt : float)
  if am_mimic__serverDeathAt < act.curTime
    destroyEntity(eid)

[es(on_appear, after=init_rnd_walkspeed)]
def init_irratic_speed_save(evt : Event; navmesh_phys__maxWalkSpeed : float; var irratic_walk__speedSave : float&)
  irratic_walk__speedSave = navmesh_phys__maxWalkSpeed


[es(tag=server, no_order, REQUIRE_NOT=(sleeping_monster, deadEntity))]
def am_mimic_update(act : UpdateStageInfoAct;
                    eid : EntityId;
                    am_mimic__sleepTemplate : string;
                    am_mimic__updateInterval : float;
                    am_mimic__sleepAfterNoTarget : float;
                    walker_agent__targetEid : EntityId;
                    agent_off_navmesh : Tag const?;
                    var am_mimic__lastValidTargetStamp : float&;
                    var am_mimic__updateAt : float&)
  if am_mimic__updateAt < act.curTime
    am_mimic__updateAt = act.curTime + am_mimic__updateInterval
    var hasTarget = false
    query(walker_agent__targetEid) <| $ [es] (isAlive : bool)
      hasTarget = isAlive
    if hasTarget
      am_mimic__lastValidTargetStamp = act.curTime
    if agent_off_navmesh == null && act.curTime - am_mimic__lastValidTargetStamp > am_mimic__sleepAfterNoTarget
      remote_change_sub_template(eid, "", am_mimic__sleepTemplate)


[es(tag=server, on_disappear, REQUIRE=(sleeping_monster))]
def on_mimic_stopped_sleeping(evt : Event; var am_mimic__lastValidTargetStamp : float&)
  am_mimic__lastValidTargetStamp = get_sync_time()


[es(tag=server, on_appear)]
def mimic_dont_sleep_on_appear(evt : Event; var am_mimic__lastValidTargetStamp : float&)
  am_mimic__lastValidTargetStamp = get_sync_time()


[es(tag=server, REQUIRE_NOT=sleeping_monster_awake_forbidden, REQUIRE=am_mimic)]
def set_mimic_disturber_as_target(evt : CmdAwakeSleepingMonster; var walker_agent__targetEid : EntityId&)
  walker_agent__targetEid = evt.disturber

[es(tag=server)]
def mimic_set_agro_on_awaken(evt : CmdAwakeSleepingMonster; mimic__agroOnAwakened : float; var mimic__keepInterestUntil : float&)
  mimic__keepInterestUntil = get_sync_time() + mimic__agroOnAwakened

[es(tag=server)]
def mimic_set_agro_on_hit(evt : EventOnDamaged; eid : EntityId; mimic__agroOnDamaged : float; var mimic__keepInterestUntil : float&)
  mimic__keepInterestUntil = max(mimic__keepInterestUntil, get_sync_time() + mimic__agroOnDamaged)
  send_net_event(eid, EventMimicDamaged())