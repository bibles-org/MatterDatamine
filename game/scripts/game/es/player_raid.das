require ecs
require ecs.common
require ecs.safe
require math.base
require DagorConsole
require DngActor
require DngHuman
require DagorMath
require GamePhys
require game.utils.spawn_base
require game.events.events_game
require game.es.item_equip_common
require game.events.events_active_matter
require game.events.player_events
require game.utils.spawn
require game.es.onboarding_common


[es(tag=server, REQUIRE=player_session)]
def player_raid_on_recreate_possessed_request(evt : CmdRecreatePossessedRequest)
  query(evt.playerEid) <| $ [es] (possessed : EntityId;
                                  team : int;
                                  var initialHeroItems : Array)
    if !is_onboarding() // onboarding has a fake raid, during which we don't save player items
      save_player_items(initialHeroItems, possessed)

    var tm : float3x4
    query(possessed) <| $ [es] (transform : float3x4)
      tm = transform

    destroyEntity(possessed)

    using() <| $(var params : Object)
      params |> set("transform", tm)
      params |> set("createEntityExtraTemplate", "recreated_possessed")
      params |> set("team", team)
      spawn_soldier(team, evt.playerEid, params)


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=nexus_militant)]
def create_death_point_on_hero_death(evt : EventEntityDied;
                                     eid aka hero_eid : EntityId;
                                     transform : float3x4)
  createEntity("minimap_death_point") <| $(init)
    init |> set("minimap_death_point__position", transform[3])
    init |> set("minimap_death_point__hero", hero_eid)


[es(tag=gameClient, REQUIRE_NOT=marker_self_destroy)]
def self_destroy_death_point_when_too_close(act : ParallelUpdateFrameDelayed;
                                            eid aka minimap_death_point_eid : EntityId;
                                            minimap_death_point__hero : EntityId;
                                            minimap_death_point__position : float3;
                                            minimap_death_point__deactivationDistanceSq : float)
  find_query() <| $ [es(REQUIRE=hero, REQUIRE_NOT=deadEntity)] (eid aka hero_eid : EntityId;
                                                                transform : float3x4)
    if minimap_death_point__hero != hero_eid && distance_sq(minimap_death_point__position, transform[3]) <= minimap_death_point__deactivationDistanceSq
      addSubTemplate(minimap_death_point_eid, "marker_self_destroy")
    return true