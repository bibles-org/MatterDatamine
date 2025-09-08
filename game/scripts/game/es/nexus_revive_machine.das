require app
require ecs
require ecs.safe
require math.base
require strings
require game.es.revive_common
require game.events.events
require game.events.events_game
require game.utils.net_utils
require game.events.events_active_matter
require pathfinder
require DngNet
require DagorMath
require DagorSystem


def is_possessed_alive(possessed : EntityId)
  var result = false
  query(possessed) <| $ [es] (isAlive : bool = true)
    result = isAlive
  return result


[es(tag=gameClient, REQUIRE=nexus_revive_machine)]
def nexus_revive_machine_prepare_interaction_menu(evt : CmdPrepareInteractionMenu;
                                                  eid aka interactable_eid : EntityId;
                                                  team aka interactable_team : int const?;
                                                  var interaction_menu : Array;
                                                  var interaction_menu_available : bool&)
  query(evt.interactorEid) <| $ [es(REQUIRE=hero)] (team aka hero_team : int;
                                                    possessedByPlr : EntityId)
    interaction_menu |> clear()

    if interactable_team != null && *interactable_team != hero_team
      send_net_event(evt.interactorEid, CmdHeroLogExEvent(event = "", key = "hud/revive_machine_access_denied"), target_entity_conn(evt.interactorEid))
      interaction_menu_available = false
      return

    find_query() <| $ [es] (team__id : int;
                            team__memberEids : EidList)
      if team__id != hero_team
        return false

      for memberEid in team__memberEids
        if memberEid == possessedByPlr
          continue

        query(memberEid) <| $ [es(REQUIRE=player)] (name : string;
                                                    possessed : EntityId)
          if is_possessed_alive(possessed)
            return

          using() <| $(var object : Object)
            object |> set("loc", "hud/revive_machine_player_hint")
            object |> set("action", "revive_{memberEid}")
            object |> set("closeInteraction", true)

            using() <| $(var action_param_object : Object)
              action_param_object |> set("playerEid", memberEid)
              object |> set("actionParam", action_param_object)

            using() <| $(var loc_param_object : Object)
              loc_param_object |> set("playerName", name)
              loc_param_object |> set("amPrice", get_current_revive_price(memberEid))
              object |> set("locParam", loc_param_object)


            interaction_menu |> push(object)

      return true

    interaction_menu_available = length(interaction_menu) > 0
    sendEvent(interactable_eid, EventActionMarkerStateChanged())

    if !interaction_menu_available
      send_net_event(evt.interactorEid, CmdHeroLogExEvent(event = "", key = "hud/revive_machine_no_players"), target_entity_conn(evt.interactorEid))


def nexus_revive_machine_revive_request(hero_eid : EntityId;
                                        nexus_revive_machine_eid : EntityId;
                                        revive_player_eid : EntityId)
  query(hero_eid) <| $ [es] (possessedByPlr aka hero_possessedByPlr : EntityId;
                             transform aka hero_transform : float3x4;
                             team aka hero_team : int;
                             am_storage__value : int;
                             human_use_object__useMinMaxDist : float2)
    if revive_player_eid == hero_possessedByPlr
      logwarn("[NEXUS_REVIVE_MACHINE] Hero is trying to revive himself! (hero_eid={hero_eid} revive_player_eid={revive_player_eid} nexus_revive_machine_eid={nexus_revive_machine_eid})")
      return
    query(nexus_revive_machine_eid) <| $ [es] (transform aka nexus_revive_machine_transform : float3x4;
                                               nexus_revive_machine__spawnOffset : float)
      let heroToMachine = nexus_revive_machine_transform[3] - hero_transform[3]
      let distSq = length_sq(heroToMachine)
      if distSq <= 1e-6 || distSq >= square(human_use_object__useMinMaxDist.y * 2.0)
        logwarn("[NEXUS_REVIVE_MACHINE] Hero is trying to use revive machine on inappropriate distance (dist={sqrt(distSq)}, human_use_object__useMinMaxDist.y={human_use_object__useMinMaxDist.y})! (hero_eid={hero_eid} revive_player_eid={revive_player_eid} nexus_revive_machine_eid={nexus_revive_machine_eid})")
        return

      query(revive_player_eid) <| $ [es] (possessed aka revive_player_possessed : EntityId;
                                          team aka revive_player_team : int)
        if is_possessed_alive(revive_player_possessed)
          logwarn("[NEXUS_REVIVE_MACHINE] Hero is trying to revive already alive player! (hero_eid={hero_eid} revive_player_eid={revive_player_eid} nexus_revive_machine_eid={nexus_revive_machine_eid})")
          return

        if hero_team != revive_player_team
          logwarn("[NEXUS_REVIVE_MACHINE] Hero is trying to revive player from enemy team! (hero_eid={hero_eid} revive_player_eid={revive_player_eid} nexus_revive_machine_eid={nexus_revive_machine_eid})")
          return

        let revivePrice = get_current_revive_price(revive_player_eid)
        if am_storage__value < revivePrice
          using() <| $(var data : Object)
            set(data, "0", am_storage__value)
            set(data, "1", revivePrice)
            send_net_event(hero_eid, CmdHeroLogExEvent(event = "", key = "hint/revive_not_enough_am", data = ecs_addr(data)), target_entity_conn(hero_eid))
          return

        let dist = sqrt(distSq)
        let heroToMachineDir = heroToMachine / dist
        var spawnPos = nexus_revive_machine_transform[3] + heroToMachineDir * nexus_revive_machine__spawnOffset
        if !project_to_nearest_navmesh_point(spawnPos, dist)
          logwarn("[NEXUS_REVIVE_MACHINE] project_to_nearest_navmesh_point failed! (spawnPos={spawnPos} hero_eid={hero_eid} revive_player_eid={revive_player_eid} nexus_revive_machine_eid={nexus_revive_machine_eid})")

        var spawnTm = hero_transform
        spawnTm[3] = spawnPos

        deactivate_player_cortical(revive_player_eid)

        sendEventImmediate(hero_eid, CmdChangeActiveMatterBalance(change = -revivePrice))
        sendEvent(revive_player_eid, CmdSpawnEntity(tm = spawnTm))


[es(tag=server, REQUIRE=nexus_revive_machine)]
def nexus_revive_machine_on_menu_action(evt : RequestInteractionMenuAction;
                                        eid aka nexus_revive_machine_eid : EntityId)
  if evt.actionParam == null
    logwarn("[NEXUS_REVIVE_MACHINE] RequestInteractionMenuAction with actionParam=null (evt.heroEid={evt.heroEid})")
    return

  let revivePlayerEid = EntityId(uint((*evt.actionParam).playerEid ?? 0))
  nexus_revive_machine_revive_request(evt.heroEid, nexus_revive_machine_eid, revivePlayerEid)
