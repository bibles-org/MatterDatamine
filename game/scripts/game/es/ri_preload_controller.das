// require ecs
// require ecs.safe
// require ecs.common
// require game.es.riextra_common
// require game.events.events_active_matter
// require net
// require level
// require RendInst
// require DagorSystem


// def check_ri_to_preload(var ri_preload_controller__riList : StringList;
//                         ri_name : string)
//   let idx = ri_preload_controller__riList |> find_index(ri_name)
//   if idx >= 0
//     return

//   ri_preload_controller__riList |> push(ri_name)

//   broadcast_net_event([[CmdPreloadRiRes riExtra=ri_name]])


// [es(tag=server, on_appear)]
// def ri_preload_controller_appear(evt : Event;
//                                  var ri_preload_controller__riList : StringList)
//   query() <| $ [es] (openable_ri__opened : string)
//     check_ri_to_preload(ri_preload_controller__riList, openable_ri__opened)


// [es(tag=server, on_appear)]
// def ri_preload_controller_on_lootable_rendinst_appear(evt : Event;
//                                                       openable_ri__opened : string)
//   if openable_ri__opened == ""
//     return

//   find_query() <| $ [es] (var ri_preload_controller__riList : StringList)
//     check_ri_to_preload(ri_preload_controller__riList, openable_ri__opened)
//     return true



// def preload_ri_assets(ri_name : string)
//   let resIdx = ensure_riextra_res_idx(ri_name)
//   if resIdx >= 0
//     rendinst_updateRiExtraReqLod(uint(resIdx), 0u)


// [es(tag=netClient, on_event=(EventLevelLoaded), on_appear)]
// def ri_preload_controller_client_appear(evt : Event;
//                                         ri_preload_controller__riList : StringList)
//   if !is_level_loaded()
//     return

//   for riName in ri_preload_controller__riList
//     preload_ri_assets(string(riName))


// [es(tag=netClient)]
// def ri_preload_controller_client_preload_ri_assets(evt : CmdPreloadRiRes)
//   if !is_level_loaded()
//     find_query() <| $ [es] (var ri_preload_controller__riList : StringList)
//       if ri_preload_controller__riList |> find_index(evt.riExtra) < 0
//         ri_preload_controller__riList |> push(evt.riExtra)
//       return true
//     return

//   preload_ri_assets(evt.riExtra)