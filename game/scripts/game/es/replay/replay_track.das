require ecs
require ecs.common
require ecs.soa_template
require app
require game.es.replay.replay_track_common
require DngCamera
require DagorMath
require math.base
require DagorDataBlock
require DagorSystem
require DagorConsole
require AnimV20
require GeomNodeTree
require strings
require game.events.events_active_matter


[soa_es, es(tag=playingReplay, after=replay_set_current_time_es)]
def replay_track_set_current_keyframe(evt : UpdateStageInfoAct;
                                      replay__curTime : float;
                                      keyFrames : KeyFrame_SOA;
                                      var replay_track__currentKeyFrame : int&)
  let keyFramesCount = length(keyFrames)
  var previousKeyFrame = -1
  for i, keyFrame in 0..keyFramesCount, keyFrames
    if keyFrame.replay_track__time > replay__curTime
      replay_track__currentKeyFrame = previousKeyFrame
      return

    previousKeyFrame = i
  replay_track__currentKeyFrame = keyFramesCount - 1


def private apply_roll(roll : float; var tm : float3x4&)
  let eps = 0.0001
  if abs(roll) > eps
    let oldPos = tm[3]
    var q : quat
    euler_to_quat(0.0f, deg_to_rad(roll), 0.0f, q)
    var rotTm : float3x4
    make_tm(q, float3(0.0f, 0.0f, 0.0f), rotTm)
    tm = tm * rotTm
    tm[3] = oldPos


[soa_def]
def private replay_track_interpolate_linear(keyFrames : KeyFrame_SOA;
                                            currentKeyFrame : int;
                                            replay__curTime : float;
                                            var outTm : float3x4&;
                                            var outRoll : float&;
                                            var outFov : float&)
  let origInd = currentKeyFrame == -1 ? 0 : currentKeyFrame
  let destInd = currentKeyFrame == -1 ? 0 : clamp(origInd + 1, origInd, length(keyFrames) - 1)
  assume orig = keyFrames[origInd]
  assume dest = keyFrames[destInd]

  let t = cvt(replay__curTime, orig.replay_track__time, dest.replay_track__time, 0.0, 1.0)
  let position = lerp(orig.replay_track__position, dest.replay_track__position, t)
  let dir = slerp(dir_to_quat(orig.replay_track__direction), dir_to_quat(dest.replay_track__direction), t) |> quat_get_forward()
  let up = slerp(dir_to_quat(orig.replay_track__up), dir_to_quat(dest.replay_track__up), t) |> quat_get_forward()
  let roll = lerp(orig.replay_track__roll, dest.replay_track__roll, t)
  let fov = lerp(orig.replay_track__fov, dest.replay_track__fov, t)

  outTm[1] = up
  outTm[2] = dir
  outTm[0] = normalize(cross(outTm[1], outTm[2]))
  orthonormalize(outTm)
  outTm[3] = position
  outRoll = roll
  outFov = fov


[soa_def]
def private replay_track_interpolate_bezier(keyFrames : KeyFrame_SOA;
                                            keyFramesCount : int;
                                            currentKeyFrame : int;
                                            replay__curTime : float;
                                            var outTm : float3x4&;
                                            var outRoll : float&;
                                            var outFov : float&)
  assume k0 = keyFrames[clamp(currentKeyFrame - 1, 0, keyFramesCount - 1)]
  assume k1 = keyFrames[clamp(currentKeyFrame + 0, 0, keyFramesCount - 1)]
  assume k2 = keyFrames[clamp(currentKeyFrame + 1, 0, keyFramesCount - 1)]
  assume k3 = keyFrames[clamp(currentKeyFrame + 2, 0, keyFramesCount - 1)]

  var dirPos0, dirPos1 : float3
  make_bezier_directors(k0.replay_track__position, k1.replay_track__position, k2.replay_track__position, k3.replay_track__position, dirPos0, dirPos1, 0.33333)
  var dirDir0, dirDir1 : float3
  make_bezier_directors(k0.replay_track__direction, k1.replay_track__direction, k2.replay_track__direction, k3.replay_track__direction, dirDir0, dirDir1, 0.33333)
  var dirUp0, dirUp1 : float3
  make_bezier_directors(k0.replay_track__up, k1.replay_track__up, k2.replay_track__up, k3.replay_track__up, dirUp0, dirUp1, 0.33333)
  var dirRoll0, dirRoll1 : float
  make_bezier_directors(k0.replay_track__roll, k1.replay_track__roll, k2.replay_track__roll, k3.replay_track__roll, dirRoll0, dirRoll1, 0.33333)
  var dirFov0, dirFov1 : float
  make_bezier_directors(k0.replay_track__fov, k1.replay_track__fov, k2.replay_track__fov, k3.replay_track__fov, dirFov0, dirFov1, 0.33333)

  let t = cvt(replay__curTime, k1.replay_track__time, k2.replay_track__time, 0.0, 1.0)
  let position = bezier_interp4(k1.replay_track__position, dirPos0, dirPos1, k2.replay_track__position, t)
  let dir = normalize(bezier_interp4(k1.replay_track__direction, dirDir0, dirDir1, k2.replay_track__direction, t))
  let up = normalize(bezier_interp4(k1.replay_track__up, dirUp0, dirUp1, k2.replay_track__up, t))
  let roll = bezier_interp4(k1.replay_track__roll, dirRoll0, dirRoll1, k2.replay_track__roll, t)
  let fov = bezier_interp4(k1.replay_track__fov, dirFov0, dirFov1, k2.replay_track__fov, t)

  outTm[1] = up
  outTm[2] = dir
  outTm[0] = normalize(cross(outTm[1], outTm[2]))
  orthonormalize(outTm)
  outTm[3] = position
  outRoll = roll
  outFov = fov


[soa_es, es(tag=playingReplay, after=replay_track_set_current_keyframe)]
def replay_track_tracking(evt : UpdateStageInfoAct;
                          replay__curTime : float;
                          keyFrames : KeyFrame_SOA;
                          replay_track__useBezierInterp : bool;
                          replay_track__playRotation : bool;
                          replay_track__playPosition : bool;
                          replay_track__playRoll : bool;
                          replay_track__playFov : bool;
                          replay_track__currentKeyFrame : int)
  let keyFramesCount = length(keyFrames)
  if keyFramesCount <= 0
    return

  query(get_cur_cam_entity()) <| $ [es(REQUIRE=replay_camera__track)] (replay_camera__currentRoll : float;
                                                                       var fovSettings : float&;
                                                                       var camera__accuratePos : DPoint3&;
                                                                       var transform : float3x4&)
    var newTm = IDENT_TM
    var newRoll = 0.0
    var newFov = 100.0
    if replay_track__useBezierInterp
      replay_track_interpolate_bezier(keyFrames, keyFramesCount, replay_track__currentKeyFrame, replay__curTime, newTm, newRoll, newFov)
    else
      replay_track_interpolate_linear(keyFrames, replay_track__currentKeyFrame, replay__curTime, newTm, newRoll, newFov)

    if replay_track__playRotation
      transform[2] = newTm[2]
      transform[1] = newTm[1]
      transform[0] = newTm[0]

    if replay_track__playRoll
      apply_roll(newRoll, transform)
    else
      apply_roll(replay_camera__currentRoll, transform)

    if replay_track__playPosition
      transform[3] = newTm[3]

    if replay_track__playFov
      fovSettings = newFov

    camera__accuratePos = DPoint3(transform[3])


[es(tag=playingReplay)]
def replay_track_play_all_es(evt : ReplayTrackPlayAll;
                             var replay_track__playRotation : bool&;
                             var replay_track__playPosition : bool&;
                             var replay_track__playRoll : bool&)
  replay_track__playRotation = true
  replay_track__playPosition = true
  replay_track__playRoll = true


[es(tag=playingReplay, before=replay_track_tracking)]
def replay_track_toggle_playing_rotation_es(evt : ReplayTrackTogglePlayRotation;
                                            var replay_track__playRotation : bool&)
  replay_track__playRotation = !replay_track__playRotation
  if !replay_track__playRotation
    find_query() <| $ [es(REQUIRE=replay_camera__track)] (camera__active : bool;
                                                          transform : float3x4;
                                                          var replay_camera__tpsInputAngle : float2&;
                                                          var replay_camera__tpsCurAng : float2&)
      if camera__active
        let dir = transform[2]
        replay_camera__tpsInputAngle = float2(-atan2(dir.x, dir.z), safe_asin(dir.y))
        replay_camera__tpsCurAng = replay_camera__tpsInputAngle
        return true
      return false


[es(tag=playingReplay)]
def replay_track_toggle_playing_position_es(evt : ReplayTrackTogglePlayPosition;
                                            var replay_track__playPosition : bool&)
  replay_track__playPosition = !replay_track__playPosition


[es(tag=playingReplay)]
def replay_track_toggle_playing_roll_es(evt : ReplayTrackTogglePlayRoll;
                                        var replay_track__playRoll : bool&)
  replay_track__playRoll = !replay_track__playRoll


[es(tag=playingReplay)]
def replay_track_toggle_playing_fov_es(evt : ReplayTrackTogglePlayFov;
                                       var replay_track__playFov : bool&)
  replay_track__playFov = !replay_track__playFov


[es(tag=playingReplay)]
def replay_track_toggle_interpolation(evt : ReplayTrackToggleInterp;
                                      var replay_track__useBezierInterp : bool&)
  replay_track__useBezierInterp = !replay_track__useBezierInterp


[soa_es, es(tag=playingReplay)]
def replay_track_save_keyframe(evt : ReplayTrackSaveKeyFrame;
                               eid : EntityId;
                               replay__curTime : float;
                               var keyFrames : KeyFrame_SOA&;
                               var replay_track__currentKeyFrame : int&)
  var position = float3(0.0, 0.0, 0.0)
  var direction = float3(0.0, 0.0, 0.0)
  var up = float3(0.0, 0.0, 0.0)
  var roll = 0.0
  var fov = 100.0
  query(get_cur_cam_entity()) <| $ [es(REQUIRE=replay_camera__tpsFreeNoTrack)] (transform : float3x4;
                                                                                replay_camera__tpsCurAng : float2;
                                                                                replay_camera__currentRoll : float;
                                                                                fov aka replay_camera__fov : float)
    position = transform[3]

    var copyTransform = transform
    var tmY, tmX = IDENT_TM
    rotyTM(replay_camera__tpsCurAng.x, tmY)
    rotxTM(replay_camera__tpsCurAng.y, tmX)
    copyTransform = tmY * tmX

    direction = copyTransform[2]
    up = copyTransform[1]
    roll = replay_camera__currentRoll
    fov = replay_camera__fov

    if replay_track__currentKeyFrame != -1 && replay__curTime == keyFrames[replay_track__currentKeyFrame].replay_track__time
      keyFrames[replay_track__currentKeyFrame].replay_track__position = position
      keyFrames[replay_track__currentKeyFrame].replay_track__direction = direction
      keyFrames[replay_track__currentKeyFrame].replay_track__up = up
      keyFrames[replay_track__currentKeyFrame].replay_track__roll = roll
      keyFrames[replay_track__currentKeyFrame].replay_track__fov = fov
      return

    keyFrames |> emplace(KeyFrame(
        replay_track__time = replay__curTime,
        replay_track__position = position,
        replay_track__direction = direction,
        replay_track__up = up,
        replay_track__roll = roll,
        replay_track__fov = fov
      ), replay_track__currentKeyFrame + 1)

    ++replay_track__currentKeyFrame
    sendEvent(eid, ReplayTrackSerialize())


[soa_es, es(tag=playingReplay)]
def replay_track_delete_keyframe(evt : ReplayTrackDeleteKeyFrame;
                                 eid : EntityId;
                                 var keyFrames : KeyFrame_SOA&;
                                 var replay_track__currentKeyFrame : int&)
  let keyFramesCount = length(keyFrames)
  if evt.index < 0 || keyFramesCount <= evt.index
    return

  erase(keyFrames, evt.index)
  if evt.index <= replay_track__currentKeyFrame
    --replay_track__currentKeyFrame
  sendEvent(eid, ReplayTrackSerialize())


[soa_es, es(tag=playingReplay)]
def replay_track_clear_all_keyframes(evt : ReplayTrackClearAllKeyFrames;
                                     var keyFrames : KeyFrame_SOA&;
                                     var replay_track__currentKeyFrame : int&)
  keyFrames |> clear()
  replay_track__currentKeyFrame = -1


[soa_es, es(tag=playingReplay)]
def replay_track_serialize(evt : ReplayTrackSerialize;
                           keyFrames : KeyFrame_SOA)
  using() <| $(var blk : DataBlock)
    for keyFrame in keyFrames
      blk |> datablock_add_new_block("key_frame") <| $(keyFrameBlk)
        keyFrameBlk |> add("time", keyFrame.replay_track__time)
        keyFrameBlk |> add("up", keyFrame.replay_track__up)
        keyFrameBlk |> add("direction", keyFrame.replay_track__direction)
        keyFrameBlk |> add("position", keyFrame.replay_track__position)
        keyFrameBlk |> add("roll", keyFrame.replay_track__roll)
        keyFrameBlk |> add("fov", keyFrame.replay_track__fov)
    datablock_save_to_text_file(blk, "ReplayTrack.blk")


def private verify_blk_params(blk : DataBlock?)
  if blk != null
    if datablock_param_exists(*blk, "time", -1)
      if datablock_param_exists(*blk, "position", -1)
        if datablock_param_exists(*blk, "direction", -1)
          if datablock_param_exists(*blk, "up", -1)
            if datablock_param_exists(*blk, "roll", -1)
              return true
  return false


[soa_es, es(tag=playingReplay)]
def replay_track_deserialize(evt : ReplayTrackDeserialize;
                             var keyFrames : KeyFrame_SOA&)
  var loaded = false
  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, "ReplayTrack.blk", DataBlockReadFlag.ROBUST)
      logerr("Error on reading ReplayTrack.blk, check whether file exists")
      return
    keyFrames |> resize(int(blk.blockCount))
    for i, keyFrame in 0u..blk.blockCount, keyFrames
      let keyFrameBlk = blk |> datablock_get_block(i)
      if verify_blk_params(keyFrameBlk)
        keyFrame.replay_track__time = datablock_getReal(keyFrameBlk, "time", 0.0)
        keyFrame.replay_track__position = datablock_getPoint3(*keyFrameBlk, "position", float3(0.f, 0.f, 0.f))
        keyFrame.replay_track__direction = datablock_getPoint3(*keyFrameBlk, "direction", float3(1.f, 0.f, 0.f))
        keyFrame.replay_track__up = datablock_getPoint3(*keyFrameBlk, "up", float3(0.f, 1.f, 0.f))
        keyFrame.replay_track__roll = datablock_getReal(*keyFrameBlk, "roll", 0.0)
        keyFrame.replay_track__fov = datablock_getReal(*keyFrameBlk, "fov", 100.0)
      else
        logerr("Unsuppoted format of ReplayTrack.blk")
        keyFrames |> clear()
        loaded = false
        break
      loaded = true
  if loaded
    console_print("ReplayTrack loaded")
    if evt.switchCamera
      broadcastEvent(ReplaySetTrackCamera())


[es(tag=playingReplay, REQUIRE=replay_track)]
def replay_track_load_on_rewind(evt : CmdReplayRewindLoadState;
                                eid : EntityId)
  assume state = evt.state
  if state != null
    let loadKeyFrames = *state |> get_bool("replay_track_load_key_frames") ?? false
    if loadKeyFrames
      sendEvent(eid, ReplayTrackDeserialize(switchCamera = false))
    let loadPostProductionEntities = *state |> get_bool("replay_post_production_load_entities") ?? false
    if loadPostProductionEntities
      sendEvent(eid, ReplayPostProdLoadFile())


[es(tag=playingReplay, REQUIRE=postProductionEntity, REQUIRE_NOT=daeditor__previewEntity, on_appear)]
def schedule_entity_for_saving(evt : Event;
                               eid : EntityId;
                               post_production_entity__savingTemplate : string;
                               transform : float3x4)
  let postProdEntityTemplate = "+post_production_entity"
  var templName = getEntityTemplateName(eid)
  templName = replace(templName, postProdEntityTemplate, "")
  createEntity(post_production_entity__savingTemplate) <| $(var init : ComponentsInitializer)
    set(init, "saving_entity__template", templName)
    set(init, "saving_entity__creationTime", get_sync_time())
    set(init, "transform", transform)
    set(init, "saving_entity__isAutoDestroy", has(eid, "autodeleteEffectEntity"))


[soa_es, es(tag=playingReplay, REQUIRE=replayPostProduction, before=post_production_save_entities_into_file)]
def save_entity_for_post_prod_es(evt : ReplayPostProdSaveFile;
                                 var postProductionEntities : PostProductionEntity_SOA&)
  query() <| $ [es(REQUIRE=postProductionEntityToSave)] (eid : EntityId;
                                                         transform : float3x4;
                                                         saving_entity__creationTime : float;
                                                         saving_entity__template : string;
                                                         saving_entity__isAutoDestroy : bool)
    push(postProductionEntities, PostProductionEntity(
      replay_post_production__creationTime = saving_entity__creationTime,
      replay_post_production__template = saving_entity__template,
      replay_post_production__transform = transform,
      replay_post_production__isAutoDestroy = saving_entity__isAutoDestroy))
    destroyEntity(eid)


[soa_es, es(tag=playingReplay, REQUIRE=replayPostProduction)]
def post_production_save_entities_into_file(evt : ReplayPostProdSaveFile;
                                            postProductionEntities : PostProductionEntity_SOA)
  using() <| $(var blk : DataBlock)
    for entity in postProductionEntities
      blk |> datablock_add_new_block("post_production_entity") <| $(postProdEntBlk)
        postProdEntBlk |> add("time", entity.replay_post_production__creationTime)
        postProdEntBlk |> add("tmpl", string(entity.replay_post_production__template))
        postProdEntBlk |> add("tm", entity.replay_post_production__transform)
        postProdEntBlk |> add("autoDestroy", entity.replay_post_production__isAutoDestroy)
    datablock_save_to_text_file(blk, "PostProduction.blk")


def private verify_postprod_blk_params(blk : DataBlock?)
  if blk != null
    if datablock_param_exists(*blk, "time", -1)
      if datablock_param_exists(*blk, "tmpl", -1)
        if datablock_param_exists(*blk, "tm", -1)
          if datablock_param_exists(*blk, "autoDestroy", -1)
            return true
  return false


[soa_es, es(tag=playingReplay, before=post_production_creation_es, REQUIRE=replayPostProduction)]
def post_production_load_entities_from_file(evt : ReplayPostProdLoadFile;
                                            var postProductionEntities : PostProductionEntity_SOA&)
  var loaded = false
  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, "PostProduction.blk", DataBlockReadFlag.ROBUST)
      logerr("Error on reading PostProduction.blk, check whether file exists")
      return
    postProductionEntities |> resize(int(blk.blockCount))
    for i, entity in 0u..blk.blockCount, postProductionEntities
      let keyFrameBlk = blk |> datablock_get_block(i)
      if verify_postprod_blk_params(keyFrameBlk)
        entity.replay_post_production__creationTime = datablock_getReal(keyFrameBlk, "time", 0.0)
        entity.replay_post_production__template := datablock_getStr(*keyFrameBlk, "tmpl", "")
        entity.replay_post_production__transform = datablock_getTm(*keyFrameBlk, "tm", IDENT_TM)
        entity.replay_post_production__isAutoDestroy = datablock_getBool(*keyFrameBlk, "autoDestroy", false)
      else
        logerr("Unsuppoted format of PostProduction.blk")
        postProductionEntities |> clear()
        loaded = false
        break
      loaded = true
  if loaded
    console_print("Post production entities loaded")


[soa_es, es(tag=playingReplay, REQUIRE=replayPostProduction)]
def post_production_creation_es(evt : ReplayPostProdLoadFile;
                                replay_post_production__creatingTemplate : string;
                                postProductionEntities : PostProductionEntity_SOA)
  let curTime = get_sync_time()
  for entity in postProductionEntities
    if entity.replay_post_production__isAutoDestroy && curTime > entity.replay_post_production__creationTime
      continue
    createEntity(replay_post_production__creatingTemplate) <| $(var init : ComponentsInitializer)
      set(init, "creating_entity__creationTime", entity.replay_post_production__creationTime)
      set(init, "creating_entity__template", entity.replay_post_production__template)
      set(init, "creating_entity__transform", entity.replay_post_production__transform)


[es(tag=playingReplay, no_order)]
def post_production_creating_entity_es(info : UpdateStageInfoAct;
                                       eid : EntityId;
                                       creating_entity__creationTime : float;
                                       creating_entity__template : string;
                                       creating_entity__transform : float3x4)
  if info.curTime > creating_entity__creationTime
    createEntity(creating_entity__template) <| $(var init : ComponentsInitializer)
      set(init, "transform", creating_entity__transform)
    destroyEntity(eid)
