options no_aot
require ecs
require ecs.soa_template
require app
require strings
require DagorConsole
require DagorDebug3D
require game.events.events_active_matter
require game.es.replay.replay_track_common
require ecs.ecs_template
require AnimV20
require GeomNodeTree


def try_delete_key_frame(replay_track_eid : EntityId; key_frame_index : int; key_frame_count : int)
  if 0 <= key_frame_index && key_frame_index < key_frame_count
    sendEvent(replay_track_eid, ReplayTrackDeleteKeyFrame(index = key_frame_index))
    console_print("KeyFrame[{key_frame_index}] deleted")
  else
    console_print("KeyFrame[{key_frame_index}] doesn't exist => can't be deleted")


[console_cmd(name="replay_track.save_file")]
def replay_track_serialize_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackSerialize())
    console_print("ReplayTrack saved")
    return true


[console_cmd(name="replay_track.load_file")]
def replay_track_deserialize_cmd(switch_camera : bool = false)
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackDeserialize(switchCamera = switch_camera))
    return true


[console_cmd(name="replay_track.save_key_frame")]
def replay_track_save_key_frame_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackSaveKeyFrame())
    console_print("KeyFrame saved")
    return true


[console_cmd(name="replay_track.delete_key_frame")]
def replay_track_delete_key_frame_cmd(index : int)
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId;
                                                replay_track__time : FloatList)
    try_delete_key_frame(eid, index, length(replay_track__time))
    return true


[console_cmd(name="replay_track.delete_current_key_frame")]
def replay_track_delete_current_key_frame_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId;
                                                replay_track__time : FloatList;
                                                replay_track__currentKeyFrame : int)
    try_delete_key_frame(eid, replay_track__currentKeyFrame, length(replay_track__time))
    return true


[console_cmd(name="replay_track.delete_all_key_frames")]
def replay_track_delete_all_key_frames_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackClearAllKeyFrames())
    console_print("All KeyFrames deleted")
    return true


[console_cmd(name="replay_track.status")]
def replay_track_status_cmd()
  find_query() <| $ [soa_blk, es(REQUIRE=replay_track)] (keyFrames : KeyFrame_SOA;
                                                         replay__curTime : float;
                                                         replay_track__currentKeyFrame : int)
    let time = "Current Time: {replay__curTime}; "
    let index = "Current KeyFrame: {replay_track__currentKeyFrame}; "
    let count = "KeyFrames Count: {length(keyFrames)}; "
    console_print("Replay Track Status => {time}{index}{count}")
    for i, keyFrame in 0..length(keyFrames), keyFrames
      let keyFrameString = keyFrameToString(i, keyFrame.replay_track__time, keyFrame.replay_track__position, keyFrame.replay_track__direction, keyFrame.replay_track__up, keyFrame.replay_track__roll, keyFrame.replay_track__fov)
      let selectedString = i == replay_track__currentKeyFrame ? ">>" : "  "
      console_print("{selectedString}{keyFrameString}")
    return true


[console_cmd(name="replay_postproduction.save_entities")]
def replay_post_production_save_cmd()
  find_query() <| $ [es(REQUIRE=replayPostProduction)] (eid : EntityId)
    sendEvent(eid, ReplayPostProdSaveFile())
    return true


[console_cmd(name="replay_postproduction.load_entities")]
def replay_post_production_load_cmd()
  find_query() <| $ [es(REQUIRE=replayPostProduction)] (eid : EntityId)
    sendEvent(eid, ReplayPostProdLoadFile())
    return true


[ecs_template]
struct draw_post_production_entities_to_save
  draw_post_production_entities : Tag


[console_cmd(name="replay_postproduction.draw_post_production_save_list")]
def replay_post_production_draw_save_list()
  let found = find_query() <| $ [es(REQUIRE=draw_post_production_entities_to_save)] (eid : EntityId)
    destroyEntity(eid)
    console_print("Post production save list draw OFF")
    return true
  if !found
    createEntity("draw_post_production_entities_to_save")
    console_print("Post production save list draw ON")


[es(tag=gameClient, no_order, REQUIRE=draw_post_production_entities)]
def replay_post_production_drawing(info : UpdateStageInfoRenderDebug)
  query() <| $ [es(REQUIRE=postProductionEntityToSave)] (transform : float3x4;
                                                         saving_entity__template : string;
                                                         saving_entity__creationTime : float)
    begin_draw_cached_debug_lines(false, false, false)

    draw_cached_debug_sphere(transform[3], 0.25, E3DCOLOR(0xFFFF0000), 8)
    add_debug_text_mark(transform[3], "time = {saving_entity__creationTime}, template = {saving_entity__template}", -1, 3.5f, E3DCOLOR(0x00000000))

    end_draw_cached_debug_lines()


[console_cmd(name="replay_track.toggle_bezier_interpolation")]
def replay_track_toggle_interpolation_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackToggleInterp())
    return true


[console_cmd(name="replay_track.play_all")]
def replay_track_play_all_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackPlayAll())
    return true


[console_cmd(name="replay_track.play_rotation")]
def replay_track_play_rotation_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackTogglePlayRotation())
    return true


[console_cmd(name="replay_track.play_position")]
def replay_track_play_position_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackTogglePlayPosition())
    return true


[console_cmd(name="replay_track.play_roll")]
def replay_track_play_roll_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackTogglePlayRoll())
    return true


[console_cmd(name="replay_track.play_fov")]
def replay_track_play_fov_cmd()
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId)
    sendEvent(eid, ReplayTrackTogglePlayFov())
    return true


[console_cmd(name="replay_track.attach_to_weapon")]
def replay_track_attach_to_weapon_cmd()
  find_query() <| $ [es(REQUIRE=replay_camera__trackWeaponEid)] (eid : EntityId)
    sendEvent(eid, ReplayTrackAttachToWeapon())
    return true


[console_cmd(name="replay_track.detach_from_weapon")]
def replay_track_detach_from_weapon_cmd()
  find_query() <| $ [es(REQUIRE=replay_camera__trackWeaponEid)] (eid : EntityId)
    sendEvent(eid, ReplayTrackDetachFromWeapon())
    return true


[ecs_template]
struct draw_replay_camera_trajection
  draw_replay_camera_trajection : Tag


[console_cmd(name="replay_track.draw_trajectory")]
def replay_track_toggle_draw_trajectory()
  let found = find_query() <| $ [es(REQUIRE=draw_replay_camera_trajection)] (eid : EntityId)
    destroyEntity(eid)
    console_print("Trajectory draw OFF")
    return true
  if !found
    createEntity("draw_replay_camera_trajection")
    console_print("Trajectory draw ON")


[es(tag=gameClient, no_order, REQUIRE=draw_replay_camera_trajection)]
def replay_track_draw_trajectory(evt : UpdateStageInfoAct)
  query() <| $ [es(REQUIRE=replay_track)] (replay_track__position : Point3List)
    let n = length(replay_track__position)
    for i in range(0..n)
      let p0 = replay_track__position[clamp(i - 1, 0, n - 1)]
      let p1 = replay_track__position[clamp(i + 0, 0, n - 1)]
      let p2 = replay_track__position[clamp(i + 1, 0, n - 1)]
      let p3 = replay_track__position[clamp(i + 2, 0, n - 1)]

      // Draw current key frame position
      draw_debug_sphere_buffered(p1, 0.5, E3DCOLOR(0xFFFF0000), 12, 1)
      add_debug_text_mark(p1, "{i}", -1, -0.5, E3DCOLOR(0xFFFF0000))

      // Draw linear lines between neighbour key frame positions
      draw_debug_line_buffered(p1, p2, E3DCOLOR(0xFFFF0000), 1)

      var d0, d1 : float3
      make_bezier_directors(p0, p1, p2, p3, d0, d1, 0.33333)

      // Draw directors and lines connecting them to the key frame positions
      draw_debug_sphere_buffered(d0, 0.25, E3DCOLOR(0xFF00FF00), 12, 1)
      draw_debug_sphere_buffered(d1, 0.25, E3DCOLOR(0xFF00FF00), 12, 1)
      draw_debug_line_buffered(p1, d0, E3DCOLOR(0xFF00FF00), 1)
      draw_debug_line_buffered(p2, d1, E3DCOLOR(0xFF00FF00), 1)

      // Draw bezier curve
      for j in range(1..20)
        let t0 = float(j - 1) / 20.0
        let s0 = bezier_interp4(p1, d0, d1, p2, t0)
        let t = float(j) / 20.0
        let s = bezier_interp4(p1, d0, d1, p2, t)
        draw_debug_line_buffered(s0, s, E3DCOLOR(0xFF0000FF), 1)
