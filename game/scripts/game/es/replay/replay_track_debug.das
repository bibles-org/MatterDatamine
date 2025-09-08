options no_aot
require ecs
require ecs.common
require ecs.soa_template
require app
require DagorConsole
require game.es.replay.replay_track_common
require game.events.events_active_matter


[console_cmd(name="replay_track.debug_enable", hint="Show changes in replay keyframes")]
def replay_track_debug_command(enable : bool = true)
  find_query() <| $ [es(REQUIRE=replay_track)] (var replay_track__debug : bool&)
    if enable ^^ replay_track__debug
      replay_track__debug = enable
      console_print("{enable ? "Enabled" : "Disabled"} replay track debug")
    else
      console_print("Replay track debug already {enable ? "enabled" : "disabled"}")
    return true


[soa_es, es(tag=playingReplay, track=replay_track__currentKeyFrame)]
def replay_track_debug_on_current_keyframe_changed(evt : Event;
                                                   keyFrames : KeyFrame_SOA;
                                                   replay__curTime : float;
                                                   replay_track__debug : bool;
                                                   replay_track__currentKeyFrame : int)
  if !replay_track__debug
    return

  let time = "Current Time: {replay__curTime}; "
  let index = "Current KeyFrame: {replay_track__currentKeyFrame}; "
  let count = "KeyFrames Count: {length(keyFrames)}; "
  let currentKeyFrame = keyFrameToString(keyFrames, replay_track__currentKeyFrame)
  visual_log("Current KeyFrame changed! {time}{index}{count}")
  visual_log("Current {currentKeyFrame}")


[soa_es, es(tag=playingReplay, after=replay_track_save_keyframe)]
def replay_track_debug_on_save_keyframe(evt : ReplayTrackSaveKeyFrame;
                                        keyFrames : KeyFrame_SOA;
                                        replay_track__debug : bool;
                                        replay_track__currentKeyFrame : int)
  if !replay_track__debug
    return

  let keyFrame = keyFrameToString(replay_track__currentKeyFrame,
                                  keyFrames[replay_track__currentKeyFrame].replay_track__time,
                                  keyFrames[replay_track__currentKeyFrame].replay_track__position,
                                  keyFrames[replay_track__currentKeyFrame].replay_track__direction,
                                  keyFrames[replay_track__currentKeyFrame].replay_track__up,
                                  keyFrames[replay_track__currentKeyFrame].replay_track__roll,
                                  keyFrames[replay_track__currentKeyFrame].replay_track__fov)
  visual_log("Added new {keyFrame}")


[soa_es, es(tag=playingReplay, before=replay_track_delete_keyframe)]
def replay_track_debug_on_delete_keyframe(evt : ReplayTrackDeleteKeyFrame;
                                          keyFrames : KeyFrame_SOA;
                                          replay_track__debug : bool)
  if !replay_track__debug
    return

  if evt.index < 0 || length(keyFrames) <= evt.index
    visual_log("Trying to delete KeyFrame[{evt.index}], but there is no such KeyFrame. KeyFrame count:{length(keyFrames)}")
    return

  let keyFrame = keyFrameToString(evt.index,
                                  keyFrames[evt.index].replay_track__time,
                                  keyFrames[evt.index].replay_track__position,
                                  keyFrames[evt.index].replay_track__direction,
                                  keyFrames[evt.index].replay_track__up,
                                  keyFrames[evt.index].replay_track__roll,
                                  keyFrames[evt.index].replay_track__fov)
  visual_log("Deleted {keyFrame}")


[soa_es, es(tag=playingReplay, after=replay_track_clear_all_keyframes)]
def replay_track_debug_on_clear_all_keyframes(evt : ReplayTrackClearAllKeyFrames;
                                              keyFrames : KeyFrame_SOA;
                                              replay_track__debug : bool)
  if !replay_track__debug
    return
  visual_log("All KeyFrames are cleared")
