require ecs
require app
require math.base
require DagorDataBlock
require DagorSystem
require replay
require rapidjson
require game.events.events_game


[es(tag=recordingReplay, on_event=EventLevelLoaded)]
def replay_recording_create_meta(evt : Event)
  createEntity("replay_meta") <| $(var init)
    init |> set("replay__startAt", get_sync_time())


[es(tag=recordingReplay)]
def replay_recording_write_meta(var evt : EventOnWriteReplayMetaInfo&;
                                replay__timeLabels : Array)
  assume obj = evt.replayMeta
  SetObject(obj) <| $(var item : JsonValue)
    item |> AddMember("total_play_time", get_sync_time(), obj)
    item |> AddMember("game", "active_matter", obj)
    using(JsonType.kArrayType) <| $(var timeLabels : JsonValue)
      for timeLabelMember in replay__timeLabels
        let timeLabelObj = get_ecs_object(timeLabelMember)
        if timeLabelObj != null
          let labelName = get_ecs_string(timeLabelObj, "name")
          let labelTime = get_float(timeLabelObj, "time")
          if labelName != null && labelTime != null
            using(JsonType.kObjectType) <| $(var timeLabel : JsonValue)
              timeLabel |> AddMember("name", string(*labelName), obj)
              timeLabel |> AddMember("time", *labelTime, obj)
              timeLabels |> PushBack(timeLabel, obj)
      item |> AddMember("timeLabels", timeLabels, obj)
