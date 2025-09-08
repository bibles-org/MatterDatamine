options no_aot
require ecs
require app
require net
require inventory
require DagorSystem
require DagorDataBlock
require game.es.endgame_common
require game.es.grav_zones_common
require game.es.item_equip_common
require game.es.net_console_macro
require game.es.message_queue_common
require game.es.inventory_drop_common
require game.events.events_active_matter
require game.es.objectives.objective_common


[net_console_cmd(name="am.extraction")]
def console_am_extraction(@net_player player_eid : EntityId)
  send_net_event(player_eid, CmdExtractFromBattlefield())


[net_console_cmd(name="extraction.create_extraction")]
def create_extraction(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es] (transform : float3x4)
      createEntity("extraction_point+active_extraction_point") <| $(init)
        var newTm = transform
        newTm[3] += transform[0] * 3.f
        drop_item_on_ground(newTm)
        init |> set("transform", newTm)


[net_console_cmd(name="am.simulate_battle_result")]
def console_am_simulate_battle_result(success_extraction = true; @net_player player_eid : EntityId)
  sendEventImmediate(player_eid, CmdExtractFromBattlefieldServer(isDebug = true))
  query(player_eid) <| $ [es] (player__isRentedEquipment : bool;
                               player__stats : Object;
                               player_move_tracker__trackPoints : Array;
                               currentHeroAM : int;
                               currentHeroItems : Array;
                               var player__chronotracesProgression : Object)
    let data <- get_player_battle_result_data(player_eid,
                                              success_extraction,
                                              player__isRentedEquipment,
                                              player__stats,
                                              currentHeroAM,
                                              currentHeroItems,
                                              player_move_tracker__trackPoints,
                                              player__chronotracesProgression)
    var fileName = "battle_result.json"
    dgs_get_settings() |> datablock_get_block("debug") <| $(blk)
      fileName = blk |> datablock_getStr("AMResultJsonPath", fileName)
    sendJsonToFile(fileName, data)


[net_console_cmd(name="am.correct_extraction_positions")]
def console_am_correct_extraction_positions()
  query() <| $ [es(REQUIRE=extraction_point)] (var transform : float3x4&)
    transform = get_grav_tm(transform[3])
