options no_aot
require ecs
require vehicle
require math.base
require Grid
require GridCollision
require DagorConsole
require DagorMath
require DngNet
require DagorDebug3D
require game.events.events_active_matter
require game.es.server_debug_common
require game.utils.hero


[es(tag=(dev, render), no_order, REQUIRE=loud_noise_debug)]
def debug_loud_noise(evt : UpdateStageInfoRenderDebug; loud_noise_debug__radius : float; loud_noise_debug__drawNoiseless : bool)
  let radiusSq = square(loud_noise_debug__radius)
  find_query() <| $ [es] (camera__active : bool; transform aka cam_transform : float3x4)
    if camera__active
      query() <| $ [es(REQUIRE=sleeping_monster, REQUIRE_NOT=deadEntity)] (changed_loud_noise__awakeThreshold : float;
                                                                           transform aka z_transform : float3x4;
                                                                           loud_noise__noiseVelocity : float;
                                                                           loud_noise__accumulatedNoise : float)
        if (loud_noise__accumulatedNoise > .0 || loud_noise_debug__drawNoiseless) && distance_sq(z_transform[3], cam_transform[3]) < radiusSq
          let drawRad = cvt(loud_noise__accumulatedNoise, .0, changed_loud_noise__awakeThreshold, 0.05, 1.0)
          let msg = "{int(loud_noise__accumulatedNoise)} / {int(changed_loud_noise__awakeThreshold)} ({int(loud_noise__noiseVelocity)})"
          let color = loud_noise__noiseVelocity < .0 ? E3DCOLOR(0xFF9999FF) : E3DCOLOR(0xFFFF9999)
          add_debug_text_mark(z_transform[3], msg, -1, 0., color)
          draw_cached_debug_sphere(z_transform[3], drawRad, color, 24)
    return camera__active
  query() <| $ [es(REQUIRE=hero)] (human_loud_noise__lastAmount, human_loud_noise__amount, human_loud_noise__lastIncrement : float)
    let msg = "{int(human_loud_noise__lastAmount)} | {int(human_loud_noise__amount)} ( +{int(human_loud_noise__lastIncrement)} /sec )"
    add_debug_text_mark_screen(50.f, 50.f, msg, -1, 0.f, E3DCOLOR(0xffffffff))
  query() <| $ [es(REQUIRE=heroVehicle)] (loud_noise__noisePerRpm, loud_noise__lastAmount : float;
                                          vehicle_net_phys : VehiclePhysActor;
                                          loud_noise__noisePerHorn : float;
                                          loud_noise__interval : float;
                                          vehicle_horn__player : EntityId)
    var noiseInc = loud_noise__noisePerRpm * vehicle_net_phys.phys.engineRPM
    if vehicle_horn__player != INVALID_ENTITY_ID
      noiseInc += loud_noise__noisePerHorn
    let msg = "{int(loud_noise__lastAmount / loud_noise__interval)} ( +{int(noiseInc)} /sec )"
    add_debug_text_mark_screen(50.f, 70.f, msg, -1, 0.f, E3DCOLOR(0xffffffff))


[console_cmd(name="am.loud_noise_debug")]
def console_loud_noise_debug(radius : float = 70.0; draw_noiseless : bool = true)
  let hasLoudNoiseDebug = find_query() <| $ [es(REQUIRE=loud_noise_debug)] (eid : EntityId)
    destroyEntity(eid)
    console_print("stopped drawing loud noise debug")
    return true
  if !hasLoudNoiseDebug
    createEntity("loud_noise_debug") <| $(init)
      init |> set("loud_noise_debug__radius", radius)
      init |> set("loud_noise_debug__drawNoiseless", draw_noiseless)
    console_print("started drawing loud noise debug")


[console_cmd(name="am.loud_noise_block_awakening")]
def console_loud_noise_block_awakening()
  let hadBlocker = find_query() <| $ [es(REQUIRE=loud_debug_noise_block_awakening_marker)] (eid : EntityId)
    destroyEntity(eid)
    query() <| $ [es(REQUIRE=loud_noise_block_awakening)] (eid : EntityId)
      removeSubTemplate(eid, "loud_noise_block_awakening")
    console_print("stopped blocking awakening")
    return true
  if !hadBlocker
    createEntity("loud_debug_noise_block_awakening_marker")
    query() <| $ [es(REQUIRE=loud_noise__accumulatedNoise)] (eid : EntityId)
      addSubTemplate(eid, "loud_noise_block_awakening")
    console_print("started blocking awakening")


[console_cmd(name="am.loud_noise_put_to_sleep")]
def console_loud_noise_put_to_sleep(radius : float = 20.0)
  let radiusSq = square(radius)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false
    query() <| $ [es] (eid : EntityId;
                       transform aka sleeper_transform : float3x4;
                       var loud_noise__accumulatedNoise : float&)
      if distance_sq(sleeper_transform[3], camera_transform[3]) > radiusSq
        return
      addSubTemplate(eid, "sleeping_monster")
      loud_noise__accumulatedNoise = 0.0
    return true


[console_cmd(name="am.loud_noise_around_camera")]
def console_loud_noise_around_camera(amount = 50.0; radius = 10.0)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      createEntity("loud_noise_oneshot") <| $(init)
        init |> set("loud_noise__radius", radius)
        init |> set("loud_noise__noise", amount)
        init |> set("loud_noise__pos", transform[3])
    return camera__active


def awake_around_pos(pos : float3)
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, 30.0), GridEntCheck.POS) <| $(eid : EntityId)
    sendEvent(eid, CmdAwakeSleepingMonster(propadateCount = 0))
  for_each_entity_in_grid(ecs_hash("creatures"), BSphere3(pos, 30.0), GridEntCheck.POS) <| $(eid : EntityId)
    sendEvent(eid, CmdAwakeSleepingMonster(propadateCount = 0))


[console_cmd(name="am.awake_around_camera")]
def console_awake_around_camera()
  let targetEid = get_controlled_hero()
  if targetEid == INVALID_ENTITY_ID
    return
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      if is_server()
        awake_around_pos(transform[3])
      else
        exec_server_cmd("am.awake_around_pos {transform[3].x} {transform[3].y} {transform[3].z}")
    return camera__active


[console_cmd(name="am.awake_around_pos")]
def console_awake_around_pos(x, y, z : float)
  awake_around_pos(float3(x, y, z))
