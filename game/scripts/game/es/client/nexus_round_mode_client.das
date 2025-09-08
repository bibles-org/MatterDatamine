require ecs
require BloodPuddles
require BulletHoles
require game.events.events_active_matter
require DngCamera


[es(tag=gameClient)]
def nexus_round_mode_erase_bullet_holes_on_round_change(evt : EventNexusRoundModeRoundChange)
  erase_all_bullet_holes()


[es(tag=gameClient)]
def nexus_round_mode_erase_all_blood_pupples_on_round_change(evt : EventNexusRoundModeRoundChange)
  var bloodPuddlesMgr = get_blood_puddles_mgr()
  if bloodPuddlesMgr == null
    return

  *bloodPuddlesMgr |> erasePuddles()


[es(tag=gameClient, on_event=(EventNexusRoundModeRoundChange, EventNexusRoundModeRoundDebriefing, EventNexusGameDebriefing))]
def nexus_round_mode_activate_static_camera_on_round_change(evt : Event;
                                                            is_local : bool;
                                                            var respawner__spectatorEnabled : bool&;
                                                            var activeCamName : das_string&;
                                                            var activeCamEid : EntityId&)
  if !is_local
    return
  activeCamName := ""
  destroyEntity(activeCamEid)
  activeCamEid = INVALID_ENTITY_ID
  respawner__spectatorEnabled = false
  query() <| $ [es] (var camera__active : bool&)
    camera__active = false

  find_query() <| $ [es(REQUIRE=static_cam)] (eid : EntityId)
    set_scene_camera_entity(eid)
    return true
