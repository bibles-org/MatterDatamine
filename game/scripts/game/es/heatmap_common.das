module heatmap_common shared
require ecs
require jsonwriter
require ecs.soa_template
require game.es.stat_bq_common

[soa_template]
struct HeatmapData
  heatmap_data__time : float
  heatmap_data__position : float3
  heatmap_data__action : string


[soa_def]
def make_json_row(data : HeatmapData_SOA;
                  idx : int;
                  mode : string;
                  var jw : JsonWriter)
  // CHANGES TO THIS SCHEME SHOULD BE REFLECTED IN BQ TABLE (ask devops if you don't know what it means)
  jw_key_value(jw, "game_mode", mode)
  jw_key_value(jw, "game_event_type", string(data[idx].heatmap_data__action))
  jw_key_value(jw, "coord_x", data[idx].heatmap_data__position.x)
  jw_key_value(jw, "coord_y", data[idx].heatmap_data__position.y)
  jw_key_value(jw, "coord_z", data[idx].heatmap_data__position.z)
  jw_key_value(jw, "time_from_game_start", data[idx].heatmap_data__time)


[soa_def]
def make_json_string(data_array : HeatmapData_SOA;
                     session_id : uint64;
                     mode : string;
                     var jw : JsonWriter&)
  jw_array(jw) <|
    for i in range(length(data_array))
      jw_obj(jw) <|
        jw_key_value(jw, "session id", session_id)
        make_json_row(data_array, i, mode, jw)
  return jw.result


[soa_def]
def send_json(data_array : HeatmapData_SOA;
              mode : string;
              event_name : string)
  for i in range(length(data_array))
    send_event_bq_with_header(event_name) <| $(var jw : JsonWriter)
      // jw_key_value(jw, "session_id", session_id) in header
      make_json_row(data_array, i, mode, jw)
