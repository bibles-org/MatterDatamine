options no_aot
require ecs
require math.base
require DagorConsole
require BehNodes
require DagorDataBlock
require DagorRandom
require Dacoll
require DagorDebug3D
require DagorTime
require daProfiler
require DngCamera
require DngActor
require MotionMatching

def get_spawn_pos_from_current_camera()
  var targetPos = float3(0, 0, 0)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      let cameraPos = transform[3]
      let dir = transform[2]
      var dist = 500.0f
      var norm : float3
      traceray_normalized(cameraPos, dir, dist, norm)
      targetPos = cameraPos + dist * dir
    return camera__active
  return targetPos

[console_cmd(name="motion_matching.spawn_changed")]
def spawn_changed()
  clear_bots()
  let spawnPos = get_spawn_pos_from_current_camera()
  var spawnTm = IDENT_TM
  spawnTm[3] = spawnPos

  let changedEid = createEntity("changed_human+am_changed_mm_component+motion_matching_camera_target") <| $(var init : ComponentsInitializer)
    set(init, "transform", spawnTm)

  createEntity("am_motion_matching_test_target") <| $(var init : ComponentsInitializer)
    set(init, "transform", spawnTm)
    set(init, "test_target_mode", "changed test 1")
    set(init, "test_target_timeToReset", 8.0)
    set(init, "test_target__followerEid", changedEid)

[console_cmd(name="motion_matching.spawn_changed_pair")]
def spawn_changed_pair()
  clear_bots()
  let spawnPos = get_spawn_pos_from_current_camera()
  var spawnTm = IDENT_TM
  spawnTm[3] = spawnPos

  using() <| $(var tester_list : EidList)
    for i in range(2)
      var templateName = "changed_human+motion_matching_debug_label"
      if i == 1
        templateName = "{templateName}+am_changed_mm_component"
      let changedEid = createEntity(templateName) <| $(var init : ComponentsInitializer)
        set(init, "transform", spawnTm)
        set(init, "motion_matching__debugLabel", i == 1 ? "motion matching" : "animtree")
        set(init, "navmesh_phys__rndWalkSpeed", float2(5.0f, 5.0f))
      createEntity("am_motion_matching_test_target") <| $(var init : ComponentsInitializer)
        set(init, "transform", spawnTm)
        set(init, "test_target_mode", "changed test 1")
        set(init, "test_target_timeToReset", 8.0)
        set(init, "test_target__followerEid", changedEid)
      tester_list |> push(changedEid)
      spawnTm[3] += spawnTm[2] * 2.0

    createEntity("animation_test_pair_base") <| $(var init : ComponentsInitializer)
      set(init, "tester_list", tester_list)
      set(init, "motion_matching__freeCameraOffset", float3(-4, 3, 0))


[console_cmd(name="motion_matching.spawn_xenohound")]
def spawn_xenohound(mode : string = "xenohound_1")
  clear_bots()
  let spawnPos = get_spawn_pos_from_current_camera()
  var spawnTm = IDENT_TM
  spawnTm[3] = spawnPos

  let changedEid = createEntity("xenohound_creature+am_xenohound_mm+motion_matching_camera_target") <| $(var init : ComponentsInitializer)
    set(init, "transform", spawnTm)
    set(init, "beh_tree__node", "xenohound_run")
  createEntity("am_motion_matching_test_target") <| $(var init : ComponentsInitializer)
    set(init, "transform", spawnTm)
    set(init, "test_target_mode", mode)
    set(init, "test_target_timeToReset", 12.0)
    set(init, "test_target__followerEid", changedEid)


[console_cmd(name="motion_matching.spawn_xenohound_pair")]
def spawn_xenohound_pair(mode : string = "xenohound_1")
  clear_bots()
  let spawnPos = get_spawn_pos_from_current_camera()
  var spawnTm = IDENT_TM
  spawnTm[3] = spawnPos

  using() <| $(var tester_list : EidList)
    for i in range(2)
      var templateName = "xenohound_creature+motion_matching_debug_label"
      if i == 0
        templateName = "{templateName}+am_xenohound_animtree"
      else
        templateName = "{templateName}+am_xenohound_mm"
      let changedEid = createEntity(templateName) <| $(var init : ComponentsInitializer)
        set(init, "transform", spawnTm)
        set(init, "motion_matching__debugLabel", i == 1 ? "motion matching" : "animtree")
        set(init, "navmesh_phys__rndWalkSpeed", float2(5.0f, 5.0f))
        set(init, "beh_tree__node", "xenohound_run")
      createEntity("am_motion_matching_test_target") <| $(var init : ComponentsInitializer)
        set(init, "transform", spawnTm)
        set(init, "test_target_mode", mode)
        set(init, "test_target_timeToReset", 12.0)
        set(init, "test_target__followerEid", changedEid)
      tester_list |> push(changedEid)
      spawnTm[3] += spawnTm[2] * 2.0

    createEntity("animation_test_pair_base") <| $(var init : ComponentsInitializer)
      set(init, "tester_list", tester_list)
      set(init, "motion_matching__freeCameraOffset", float3(-6, 5, 0))


[es(no_order)]
def am_changed_test_target_update(info : ecs::UpdateStageInfoAct;
                                  var test_target : float3&;
                                  test_target_time : float;
                                  test_target_timeToReset : float;
                                  test_target_origin : float3;
                                  test_target_mode : string)
  var offsets : array<float3>
  if test_target_mode == "changed test 1"
    offsets = array<float3>(
      float3(0.0f, 0.0f, 0.0f),
      float3(-20.0f, 0.0f, 0.0f),
      float3(-10.0f, 0.0f, 15.0f)
    )
  elif test_target_mode == "xenohound_2"
    offsets = array<float3>(
      float3(0.0f, 0.0f, 0.0f),
      float3(-2.0f, 0.0f, 6.0f),
      float3(2.0f, 0.0f, 12.0f),
      float3(-2.0f, 0.0f, 18.0f),
      float3(2.0f, 0.0f, 24.0f),
      float3(-2.0f, 0.0f, 30.0f),
      float3(2.0f, 0.0f, 28.0f),
      float3(-2.0f, 0.0f, 26.0f),
      float3(2.0f, 0.0f, 24.0f),
      float3(-2.0f, 0.0f, 20.0f),
      float3(2.0f, 0.0f, 16.0f),
      float3(-2.0f, 0.0f, 12.0f),
      float3(2.0f, 0.0f, 8.0f),
      float3(-2.0f, 0.0f, 4.0f),
    )
  elif test_target_mode == "xenohound_1"
    offsets = array<float3>(
      float3(0.0f, 0.0f, 0.0f),
      float3(-4.0f, 0.0f, 0.0f),
      float3(-4.0f, 0.0f, 4.0f),
      float3(0.0f, 0.0f, 4.0f),
      float3(-4.0f, 0.0f, 4.0f)
    )
  else
    return

  let pointNo = clamp(int(test_target_time * float(length(offsets)) / test_target_timeToReset), 0, length(offsets) - 1)
  test_target = test_target_origin + offsets[pointNo]

[es(no_order)]
def mm_animation_tester_set_target_eid(info : ecs::UpdateStageInfoAct;
                                       eid : EntityId;
                                       test_target__active : bool;
                                       test_target__followerEid : EntityId)
  query(test_target__followerEid) <| $ [es] (var walker_agent__targetEid : EntityId&)
    walker_agent__targetEid = test_target__active ? eid : INVALID_ENTITY_ID

[es(no_order)]
def xenohound_mm_animation_tester_set_target_eid(info : ecs::UpdateStageInfoAct;
                                                 eid : EntityId;
                                                 test_target__active : bool;
                                                 test_target__followerEid : EntityId)
  query(test_target__followerEid) <| $ [es] (var spawnling__parentEid : EntityId&)
    spawnling__parentEid = test_target__active ? eid : INVALID_ENTITY_ID

[es(no_order)]
def mm_animation_tester_update(info : ecs::UpdateStageInfoAct;
                               var transform : float3x4&;
                               test_target, test_target_posOffset : float3)
  transform[3] = test_target + test_target_posOffset

[es(no_order, REQUIRE=test_target__followerEid)]
def mm_animation_tester_draw_debug(evt : UpdateStageInfoRenderDebug;
                                   transform : float3x4)
  let color = E3DCOLOR(0xFFFFFF00)
  draw_debug_sphere_buffered(transform[3], 0.3, color, 12, 10)

def clear_bots()
  query() <| $ [es] (eid : EntityId;
                     test_target__followerEid : EntityId)
    destroyEntity(test_target__followerEid)
    destroyEntity(eid)
  console_command("motion_matching.clear_tester")
