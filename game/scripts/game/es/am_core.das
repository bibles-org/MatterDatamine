require ecs
require math
require math.base
require DagorRandom
require DagorMath
require game.events.events_game
require game.events.events_active_matter
require Dacoll
require DagorMathUtils
require app
require DngDm
require DngNet
require Grid
require math.random
require math.color
require DagorSystem
require game.events.events


[es(tag=server, on_appear)]
def am_core_init_server(evt : Event; transform : float3x4; am_core__timeInProtectiveModeRng : float2;
                        am_core__maxHpRng : float2; var hitpoints__hp, hitpoints__maxHp : float&;
                        var am_core__timeInProtectiveMode : float&; var am_core__moveTo : float3&)
  hitpoints__maxHp = am_core__maxHpRng.x
  hitpoints__hp = am_core__maxHpRng.x
  am_core__timeInProtectiveMode = am_core__timeInProtectiveModeRng.x
  am_core__moveTo = transform[3]


[es(tag=gameClient, on_appear)]
def am_core_create_effects(evt : Event;
                           eid : EntityId;
                           transform : float3x4;
                           am_core__effectTemplate : string)
  createEntity(am_core__effectTemplate) <| $(var init)
    let tm = transform * scale_tm(4f)
    set(init, "transform", tm)
    set(init, "game_effect__attachedTo", eid)


[es(tag=gameClient, on_appear, REQUIRE=am_core)]
def am_core_create_companion(evt : Event; eid : EntityId; transform : float3x4;
                             am_core__decorCompanionTemplate : string;
                             am_core__decorCompanionsCountRng : int2 = int2(15, 20))
  if am_core__decorCompanionTemplate != ""
    for _ in range(rnd_int(am_core__decorCompanionsCountRng))
      createEntity(am_core__decorCompanionTemplate) <| $(var init)
        set(init, "transform", transform)
        set(init, "am_core_companion__parent", eid)


[es(tag=gameClient, on_disappear)]
def am_core_garbage_collector(evt : Event; eid aka core_eid, am_core__protectiveShellEid : EntityId)
  destroyEntity(am_core__protectiveShellEid)
  query() <| $ [es] (eid : EntityId; am_core_companion__parent, game_effect__attachedTo : EntityId const?)
    if (am_core_companion__parent != null && *am_core_companion__parent == core_eid ||
        game_effect__attachedTo != null && *game_effect__attachedTo == core_eid)
      destroyEntity(eid)


[es(tag=gameClient, on_appear)]
def am_core_companion_appear(evt : Event; am_core_companion__speed : float; am_core_companion__scaleRng, am_core_companion__radiusRng,
                             am_core_companion__speedRng : float2;
                             var am_core_companion__yaw, am_core_companion__pitch, am_core_companion__yawSpeed,
                             am_core_companion__pitchSpeed, am_core_companion__radius : float&;
                             var transform : float3x4&)
  var tm = transform
  let dir = angles_to_dir(float2(rnd_float(0f, TWOPI), rnd_float(0f, TWOPI)))
  let q = dir_to_quat(dir)
  make_tm(q, tm[3], tm)
  tm = tm * scale_tm(rnd_float(am_core_companion__scaleRng))
  transform = tm

  am_core_companion__yaw = rnd_float(0f, TWOPI)
  am_core_companion__pitch = rnd_float(0f, TWOPI)
  am_core_companion__radius = rnd_float(am_core_companion__radiusRng)

  var speed = fixed_array<float>(0f, 0f)
  speed[rnd_int(0, 1)] = is_equal_float(am_core_companion__speed, 0f) ? rnd_float(am_core_companion__speedRng) : am_core_companion__speed
  am_core_companion__yawSpeed = speed[0]
  am_core_companion__pitchSpeed = speed[1]


// Physics and various effects of the core
// -------------------------------------------------------------------------------------------
[es(tag=server, no_order, REQUIRE=loc_snapshots__snapshotData)]
def am_core_phys_snapshots(info : ParallelUpdateFrameDelayed; am_core__moveTo : float3; var transform aka am_core_transform : float3x4&)
  let sinusoid = sin(info.curTime) * info.dt * 10f
  transform[3] = lerp(transform[3], float3(am_core__moveTo.x, am_core__moveTo.y + sinusoid, am_core__moveTo.z), float3(info.dt))

[es(tag=gameClient, REQUIRE=amCoreEffect, no_order)]
def am_core_effect_phys(info : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId; var transform aka effect_transform : float3x4&)
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4)
    effect_transform[3] = transform[3]

[es(tag=gameClient, no_order)]
def am_core_protective_shell_phys(info : ParallelUpdateFrameDelayed; am_core__protectiveShellEid : EntityId; transform aka core_transform : float3x4)
  query(am_core__protectiveShellEid) <| $ [es] (var transform : float3x4&)
    transform[3] = core_transform[3]

[es(tag=gameClient, no_order)]
def am_core_companion_phys(info : ParallelUpdateFrameDelayed; am_core_companion__parent : EntityId; am_core_companion__radius : float;
                           am_core_companion__yawSpeed : float; am_core_companion__pitchSpeed : float;
                           var am_core_companion__yaw : float&; var am_core_companion__pitch : float&;
                           var transform aka companion_transform : float3x4&)
  assume radius = am_core_companion__radius
  query(am_core_companion__parent) <| $ [es] (transform : float3x4)
    let additional = float3(sin(am_core_companion__yaw) * cos(am_core_companion__pitch) * radius,
                            cos(am_core_companion__yaw) * radius,
                            sin(am_core_companion__yaw) * sin(am_core_companion__pitch) * radius)
    companion_transform[3] = lerp(companion_transform[3], transform[3] + additional, float3(info.dt))
  am_core_companion__pitch += am_core_companion__pitchSpeed
  am_core_companion__yaw += am_core_companion__yawSpeed


// Protective_mode
// -------------------------------------------------------------------------------------------
[es(tag=server, track=isAlive)]
def am_core_enter_protective_mode_server(evt : Event; eid : EntityId; isAlive : bool; am_core__timeInProtectiveMode : float;
                                         am_core__fragmentsLimitDenominator : float2; var am_core__protectiveModeEndTime : float&;
                                         var am_core__fragmentsLimit : int&; var ballistic_phys__omega : float3&)
  if !isAlive && am_core__fragmentsLimit > 0
    ballistic_phys__omega = float3(0f)
    am_core__protectiveModeEndTime = get_sync_time() + am_core__timeInProtectiveMode
    sendEvent(eid, EventDropLootRequest())
    am_core__fragmentsLimit -= rnd_int(int(am_core__fragmentsLimitDenominator.x), int(am_core__fragmentsLimitDenominator.y))

[es(tag=gameClient, track=am_core__fragmentsLimit)]
def am_core_enter_protective_mode_client(evt : Event; am_core__timeInProtectiveMode : float; am_core__minMaxScale : float2;
                                         am_core__protectiveShellScaleViscosityMult : float; am_core__fragmentsLimit : int;
                                         am_core__protectiveShellTemplate : string;
                                         var am_core__protectiveShellEid : EntityId&)
  if am_core__protectiveShellTemplate != ""
    return

  destroyEntity(am_core__protectiveShellEid)
  am_core__protectiveShellEid = createEntity(am_core__protectiveShellTemplate) <| $(var init)
    set(init, "am_core__scaleViscosity", am_core__protectiveShellScaleViscosityMult * am_core__timeInProtectiveMode)
    if am_core__fragmentsLimit <= 0
      set(init, "am_core__minMaxScale", float2(am_core__minMaxScale.y))


[es(tag=gameClient, on_appear)]
def am_core_enter_protective_mode_client_init(evt : Event;
                                              var am_core__fragmentsLimit : int&)
  if am_core__fragmentsLimit <= 0
    // Workaround: Emulate default am core behavior to create protective shell
    am_core__fragmentsLimit = (am_core__fragmentsLimit == 0 ? -1 : 0)


[es(tag=server, no_order)]
def am_core_exit_protective_mode_server(info : ParallelUpdateFrameDelayed; hitpoints__maxHp : float; ballistic_phys__omegaBase : float3;
                                        am_core__fragmentsLimit : int; isAlive : bool; am_core__protectiveModeEndTime : float;
                                        var hitpoints__hp : float&; var ballistic_phys__omega : float3&)
  if !isAlive && info.curTime > am_core__protectiveModeEndTime && am_core__fragmentsLimit > 0
    hitpoints__hp = hitpoints__maxHp
    ballistic_phys__omega = ballistic_phys__omegaBase

[es(tag=gameClient, track=isAlive)]
def am_core_exit_protective_mode_client(evt : Event; isAlive : bool; var am_core__protectiveShellEid : EntityId&)
  if isAlive
    destroyEntity(am_core__protectiveShellEid)
    am_core__protectiveShellEid = INVALID_ENTITY_ID


// Loot presets
// -------------------------------------------------------------------------------------------
[es(tag=server, on_event=EventDropLootRequest, before=loot_drop_system_create_loot)]
def am_core_switch_loot_generator(evt : Event; hitpoints__maxHp : float; am_core__maxHpRng : float2;
                                  am_core__lootPresets : StringList; var loot_drop_system__lootPreset : das_string&)
  let idx = floori(cvt(hitpoints__maxHp, am_core__maxHpRng.x, am_core__maxHpRng.y, 0.f, float(length(am_core__lootPresets) - 1)))
  loot_drop_system__lootPreset := am_core__lootPresets[idx]


// Health systems and everything related with it
// -------------------------------------------------------------------------------------------
[es(tag=server, no_order)]
def am_core_regeneration(info : ParallelUpdateFrameDelayed; hitpoints__regenPerSec : float; am_core__fragmentsLimit : int;
                         hitpoints__maxHp : float; var hitpoints__hp : float&)
  if am_core__fragmentsLimit > 0 && hitpoints__hp > 0f
    hitpoints__hp = min(hitpoints__maxHp, hitpoints__hp + hitpoints__regenPerSec * info.dt)

[es(tag=gameClient, no_order, REQUIRE=am_core__fragmentsLimit)]
def am_core_color(info : ParallelUpdateFrameDelayed;
                  hitpoints__hp : float;
                  hitpoints__maxHp : float;
                  am_core_light__exhausted : E3DCOLOR;
                  am_core_light__healthy : E3DCOLOR;
                  var light__color : E3DCOLOR&)
  light__color = lerp_color(am_core_light__exhausted, am_core_light__healthy, hitpoints__hp / hitpoints__maxHp)

[es(tag=server, no_order)]
def am_core_cooling_down_act(info : ParallelUpdateFrameDelayed; am_core__coolingDownDuration : float;
                             am_core__maxHpRng : float2; am_core__maxHpStep : float; am_core__timeInProtectiveModeRng : float2;
                             am_core__timeInProtectiveModeStep : float;
                             var hitpoints__maxHp, hitpoints__hp, am_core__coolingDownEndTime : float&;
                             var am_core__timeInProtectiveMode : float&)
  let coreIsHot = hitpoints__maxHp > am_core__maxHpRng.x
  if info.curTime > am_core__coolingDownEndTime && coreIsHot
    hitpoints__maxHp = clamp(hitpoints__maxHp - am_core__maxHpStep, am_core__maxHpRng.x, am_core__maxHpRng.y)
    hitpoints__hp = min(hitpoints__hp, hitpoints__maxHp)
    am_core__timeInProtectiveMode = clamp(am_core__timeInProtectiveMode - am_core__timeInProtectiveModeStep, am_core__timeInProtectiveModeRng.x, am_core__timeInProtectiveModeRng.y)
    am_core__coolingDownEndTime = info.curTime + am_core__coolingDownDuration

[es(tag=server)]
def am_core_cooling_down_interrupt(evt : EventOnEntityHit; am_core__coolingDownDuration : float; var am_core__coolingDownEndTime : float&)
  am_core__coolingDownEndTime = get_sync_time() + am_core__coolingDownDuration

[unused_argument(am_core__fragmentsLimit), es(tag=server, track=am_core__fragmentsLimit)]
def am_core_warming_up_act(evt : Event; am_core__fragmentsLimit : int; am_core__maxHpStep, am_core__coolingDownDuration : float;
                           am_core__timeInProtectiveModeStep : float; am_core__timeInProtectiveModeRng : float2;
                           am_core__maxHpRng : float2; var hitpoints__maxHp, am_core__coolingDownEndTime : float&;
                           var am_core__timeInProtectiveMode : float&)
  hitpoints__maxHp = clamp(hitpoints__maxHp + am_core__maxHpStep, am_core__maxHpRng.x, am_core__maxHpRng.y)
  am_core__timeInProtectiveMode = clamp(am_core__timeInProtectiveMode + am_core__timeInProtectiveModeStep, am_core__timeInProtectiveModeRng.x, am_core__timeInProtectiveModeRng.y)
  am_core__coolingDownEndTime = get_sync_time() + am_core__coolingDownDuration


// Hit reaction
// -------------------------------------------------------------------------------------------
[es(tag=gameClient, REQUIRE=eid)]
def am_core_blast_wave(evt : EventOnShellExploded)
  let explosionPos = evt.explPos
  let maxRadius = get_shell_max_radius(int(evt.shellId), int(evt.damageId), int(evt.ballisticsId))
  let sphere = BSphere3(explosionPos, maxRadius)
  for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(targetEid : EntityId; targetPos : float3)
    query(targetEid) <| $ [es] (am_core__blastWaveAdd : float; var transform : float3x4&)
      let hitDir = normalize(explosionPos - targetPos)
      let mult = safediv(1f, distance_sq(explosionPos, targetPos)) + am_core__blastWaveAdd
      transform[3] -= hitDir * mult

[es(tag=gameClient)]
def am_core_hit_reaction(evt : EventOnEntityHit; eid : EntityId; isAlive : bool; am_core__minMaxScale : float2;
                         am_core__scaleAdd : float; var am_core__scale : float&)
  if isAlive && evt.victim == eid
    am_core__scale = min(am_core__minMaxScale.y, am_core__scale + am_core__scaleAdd)


// Exhaust capacity
// -------------------------------------------------------------------------------------------
[es(tag=server)]
def am_core_exhaust_capacity(evt : EventDroppedLoot;
                             eid : EntityId;
                             transform : float3x4;
                             am_core__createOnDestroyTemplate : string;
                             var am_core__maxLootCountCapactity : int&)
  am_core__maxLootCountCapactity -= evt.count
  if am_core__maxLootCountCapactity <= 0
    destroyEntity(eid)
    createEntity(am_core__createOnDestroyTemplate) <| $(var init : ComponentsInitializer)
      init |> set("ownerEid", eid)
      init |> set("transform", transform)
    broadcastEvent(EventAmCoreExhausted(eid = eid))


// Scale
// -------------------------------------------------------------------------------------------
[es(tag=gameClient, no_order)]
def am_core_scale(info : ParallelUpdateFrameDelayed; am_core__scaleViscosity : float; am_core__minMaxScale : float2;
                  var am_core__scale : float&; var transform : float3x4&)
  am_core__scale = approach(am_core__scale, am_core__minMaxScale.x, info.dt, am_core__scaleViscosity)
  var tm = transform
  tm[0] = normalize(tm[0])
  tm[1] = normalize(tm[1])
  tm[2] = normalize(tm[2])
  tm = tm * scale_tm(am_core__scale)
  transform = tm


[es(tag=server, on_appear)]
def am_core_fake_collision_init(evt : Event;
                                eid aka am_core_eid : EntityId;
                                transform aka am_core_transform : float3x4;
                                am_core_fake_collision__colliderTemplate : string)
  createEntity(am_core_fake_collision__colliderTemplate) <| $(var init : ComponentsInitializer)
    init |> set("ownerEid", am_core_eid)
    init |> set("transform", am_core_transform)


[es(tag=server, on_disappear, REQUIRE=am_core_fake_collision__colliderTemplate)]
def am_core_fake_collision_deinit(evt : Event;
                                  eid aka am_core_eid : EntityId)
  find_query() <| $ [es(REQUIRE=am_core_fake_collider)] (eid aka collider_eid : EntityId;
                                                         ownerEid : EntityId)
    if ownerEid != am_core_eid
      return false
    destroyEntity(collider_eid)
    return true


[es(tag=server, no_order)]
def am_core_fake_collider_update(act : ParallelUpdateFrameDelayed;
                                 ownerEid : EntityId;
                                 var transform aka collider_transform : float3x4)
  query(ownerEid) <| $ [es] (transform aka am_core_transform : float3x4)
    collider_transform[3] = am_core_transform[3]
