require ecs
require game.events.events
require game.events.events_active_matter
require game.es.objectives.objective_common
require math.base
require game.events.events_game
require RendInst
require DagorMath
require Grid
require game.utils.team


[es(tag=server, on_appear, REQUIRE=questDevice)]
def objective_put_device_planting(evt : Event;
                                  eid aka device_eid : EntityId;
                                  playerOwnerEid : EntityId;
                                  transform : float3x4;
                                  var quest_device__objectives : EidList&;
                                  var team aka device_team : int?;
                                  dontCompleteObjectiveOnPlanting : Tag const?)
  var mainTeam = TEAM_UNASSIGNED
  query(playerOwnerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es] (team : int;
                                human_inventory__lastUsedItemDevice : EntityId)
      mainTeam = team
      query(human_inventory__lastUsedItemDevice) <| $ [es] (quest_item__objectiveEids : EidList)
        quest_device__objectives := quest_item__objectiveEids
      if device_team != null
        *device_team = team
  if dontCompleteObjectiveOnPlanting == null
    for objective in quest_device__objectives
      do_progress_for_objective(objective)
      do_progress_on_objective_for_teammates(objective, device_team ?? TEAM_UNASSIGNED, transform)
  sendEvent(device_eid, EventOnDeviceUsed(playerEid = playerOwnerEid))


def do_progress_on_objective_for_teammates(objective_eid : EntityId; main_team : int; main_transform : float3x4)
  query(objective_eid) <| $ [es] (objective__completeForEntireTeamInRadius : float;
                                  objective__name aka main_objective__name : string;
                                  objective__playerEid aka main_objective__playerEid : EntityId)
    if objective__completeForEntireTeamInRadius > .0
      query() <| $ [es] (objective__name aka another_objective__name : string;
                         objective__currentValue, objective__requireValue : int;
                         eid aka another_eid, objective__playerEid aka another_objective__playerEid : EntityId)
        if (objective_eid != another_eid &&
            another_objective__name == main_objective__name &&
            objective__currentValue < objective__requireValue)
          query(another_objective__playerEid) <| $ [es] (possessed : EntityId)
            query(possessed) <| $ [es] (team aka another_team : int; transform aka another_transform : float3x4)
              if another_team == main_team && distance(another_transform[3], main_transform[3]) < objective__completeForEntireTeamInRadius
                print("[Contracts] complete {objective__name} for plr {another_objective__playerEid} because they are close and are teammates with {main_objective__playerEid}. {objective_eid}<{getEntityTemplateName(objective_eid)}>")
                do_progress_for_objective(another_eid)


[es(tag=server, no_order, REQUIRE=objectivePutDevice, REQUIRE_NOT=disableObjectiveUpdate)]
def objective_put_device_tick_device_timer(info : ParallelUpdateFrameDelayed;
                                           eid aka objective_eid : EntityId;
                                           objective__playerEid : EntityId)

  query() <| $ [es(REQUIRE=questDevice)] (playerOwnerEid, eid aka device_eid : EntityId;
                                          var quest_device__timer : float&;
                                          quest_device__activated : bool;
                                          var attraction__overrideAttractionMult : float?;
                                          var use_object__enabled : bool?;
                                          team : int = TEAM_UNASSIGNED;
                                          transform : float3x4;
                                          quest_device__objectives : EidList;
                                          quest_device__questItemTemplates : StringList const? = null)
    if playerOwnerEid != objective__playerEid || quest_device__activated || !has_value(quest_device__objectives, objective_eid)
      return

    quest_device__timer -= info.dt
    if quest_device__timer > 0f
      return

    if attraction__overrideAttractionMult != null
      *attraction__overrideAttractionMult = 0f

    // If the device must generate a quest item, the objective will be completed only when the player is extracted together with this item
    if quest_device__questItemTemplates != null && !empty(*quest_device__questItemTemplates)
      for itemTemplate in *quest_device__questItemTemplates
        create_quest_item_in_container(string(itemTemplate), device_eid, objective__playerEid, [ objective_eid])
      if use_object__enabled != null
        *use_object__enabled = true
      return

    do_progress_for_objective(objective_eid)
    do_progress_on_objective_for_teammates(objective_eid, team, transform)


[es(tag=server, track=objective__currentValue, REQUIRE=objectivePutDevice)]
def objective_put_device_on_quest_completion(evt : Event;
                                             eid aka objective_eid : EntityId;
                                             objective__playerEid : EntityId;
                                             objective__currentValue : int;
                                             objective__requireValue : int)
  if objective__currentValue < objective__requireValue
    return

  query() <| $ [es(REQUIRE=questDevice)] (playerOwnerEid : EntityId;
                                          var quest_device__activated : bool&;
                                          quest_device__objectives : EidList;
                                          quest_device__monsterGenEid = INVALID_ENTITY_ID)
    if playerOwnerEid != objective__playerEid || quest_device__activated || !has_value(quest_device__objectives, objective_eid)
      return
    quest_device__activated = true
    destroyEntity(quest_device__monsterGenEid)


[es(tag=server, on_appear, REQUIRE=questDevice)]
def objective_put_device_create_monster_gen(evt : Event;
                                            transform : float3x4;
                                            quest_device__monsterGenTemplate : string;
                                            quest_device__monsterGenBoundingBox : float3;
                                            var quest_device__monsterGenEid : EntityId&)
  if !empty(quest_device__monsterGenTemplate)
    quest_device__monsterGenEid = createEntity(quest_device__monsterGenTemplate) <| $(var init)
      var tm = IDENT_TM
      tm[0] *= quest_device__monsterGenBoundingBox[0]
      tm[1] *= quest_device__monsterGenBoundingBox[1]
      tm[2] *= quest_device__monsterGenBoundingBox[2]
      tm[3] = transform[3]
      set(init, "transform", tm)


[es(tag=server, on_appear, REQUIRE=quest_device__monsterGenEid)]
def objective_put_device_protect_from_monsters_create_attract_point(evt : Event;
                                                                    eid : EntityId;
                                                                    quest_device__timer : float;
                                                                    transform : float3x4)
  createEntity("attract_point") <| $(init)
    set(init, "transform", transform)
    set(init, "game_effect__timeToDestroy", quest_device__timer)
    set(init, "attract_point__ownerEid", eid)


[es(tag=server, REQUIRE=questDevice)]
def objective_put_device_on_rendinst_destroyed(evt : EventRendinstDestroyed;
                                               eid, quest_device__monsterGenEid : EntityId;
                                               ri_extra : RiExtraComponent;
                                               quest_device__objectives : EidList)
  if evt.riexHandle == ri_extra.handle
    destroyEntity(quest_device__monsterGenEid)
    destroyEntity(eid)
    for objective in quest_device__objectives
      if !has(objective, "disableObjectiveUpdate")
        set_objective_fail_status(objective, true)


[es(tag=render, no_order, REQUIRE=questDevice)]
def objective_put_device_device_light(info : ParallelUpdateFrameDelayed;
                                      quest_device__activated : bool;
                                      quest_device__activatedColor, quest_device__diactivatedColor : E3DCOLOR;
                                      quest_device__baseLightBrightness, quest_device__blinkingFrequency : float;
                                      var light__color : E3DCOLOR&;
                                      var light__brightness : float&)
  light__color = quest_device__activated ? quest_device__activatedColor : quest_device__diactivatedColor
  light__brightness = quest_device__activated ? quest_device__baseLightBrightness : quest_device__baseLightBrightness * sin(info.curTime * quest_device__blinkingFrequency)


[es(tag=server, REQUIRE=questBombDevice)]
def objective_put_device_on_bomb_device_explode(evt : EventShellExplodedServer;
                                                eid : EntityId;
                                                quest_device__objectives : EidList)
  for objective in quest_device__objectives
    do_progress_for_objective(objective)
    destroyEntity(eid)


[es(tag=server, no_order, REQUIRE=questDevice)]
def objective_put_device_monster_trap_act(info : ParallelUpdateFrameDelayed;
                                          transform : float3x4;
                                          quest_monster_trap__radius : float;
                                          quest_device__objectives : EidList;
                                          var quest_monster_trap__caughtMonsterEid : EntityId&;
                                          var use_object__enabled : bool&)
  if quest_monster_trap__caughtMonsterEid != INVALID_ENTITY_ID
    return
  var trackingTags : array<string>
  for objective in quest_device__objectives
    query(objective) <| $ [es] (objective__params : Array)
      collect_objective_param_values_by_name_strict(objective, objective__params, "monsterTrackingTag", trackingTags)
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], quest_monster_trap__radius), GridEntCheck.POS) <| $(eid : EntityId)
    if quest_monster_trap__caughtMonsterEid != INVALID_ENTITY_ID
      return
    query(eid) <| $ [es] (kill_tracking_tag : string)
      if !empty(trackingTags) && !has_value(trackingTags, kill_tracking_tag)
        return
      quest_monster_trap__caughtMonsterEid = eid
      use_object__enabled = true
  query(quest_monster_trap__caughtMonsterEid) <| $ [es] (var beh_tree__enabled : bool&;
                                                         var navmesh_phys__wishWalkSpeed : float&)
    beh_tree__enabled = false
    navmesh_phys__wishWalkSpeed = 0f


[es(tag=server, REQUIRE=monsterTrapDevice)]
def on_using_monster_trap_device(evt : CmdUse;
                                 quest_device__objectives : EidList;
                                 playerOwnerEid : EntityId;
                                 quest_monster_trap__caughtMonsterEid : EntityId;
                                 var use_object__enabled : bool&)
  if quest_monster_trap__caughtMonsterEid == INVALID_ENTITY_ID
    return
  query(evt.requesterEid) <| $ [es] (possessedByPlr : EntityId)
    if possessedByPlr == playerOwnerEid
      for objective in quest_device__objectives
        do_progress_for_objective(objective)
      use_object__enabled = false


[es(tag=server, on_appear, REQUIRE=questDevice, after=objective_put_device_planting)]
def change_objective_device_count_on_device_put(evt : Event; quest_device__objectives : EidList)
  for e in quest_device__objectives
    query(e) <| $ [es] (var objective_put_device__deviceCount : int&)
      objective_put_device__deviceCount--


[es(tag=gameClient, track=objective_put_device__deviceCount)]
def clear_quick_slot_on_device_count_change(evt : Event; objective_put_device__deviceCount : int; objective__playerEid : EntityId)
  if objective_put_device__deviceCount <= 0
    query(objective__playerEid) <| $ [es] (possessed : EntityId)
      query(possessed) <| $ [es] (var quick_use__objective : das_string&)
        quick_use__objective := ""
