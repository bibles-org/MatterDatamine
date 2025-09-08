options no_aot
require ecs
require game.es.net_console_macro
require jsonwriter
require game.es.heatmap_common
require game.es.stats_game_mode_common
require ecs.soa_template

[net_console_cmd(name="heatmap.print")]
def console_send_print_event()
  find_query() <| $ [soa_blk, es(REQUIRE=heatmap)] (heatmapData : HeatmapData_SOA)
    for modeName in get_modes()
      jw_writer() <| $(var jw : JsonWriter)
        print("heatmap stat: {make_json_string(heatmapData, get_session_id(), modeName, jw)}")
    return true