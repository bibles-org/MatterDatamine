require ecs
require DngNet
require vehicle
require DngHuman
require DngPhysObj
require DagorMath
require math.base
require game.events.events
require game.es.entity_mods_common
require game.events.inventory_events
require game.events.events_game
require game.events.events_active_matter
require danetlibs.weapons.melee_events
require game.es.loud_noise_common
require Action
require AnimV20
require GeomNodeTree


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def loud_noise_update_es(act : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         loud_noise_reaction__interval : float;
                         loud_noise__maxFadeVelocity : float;
                         loud_noise__noiseVelocityFade : float;
                         var loud_noise__prevAccumulatedNoise : float&;
                         var loud_noise__noiseVelocity : float&;
                         var loud_noise_reaction__wasDisturbed : bool&;
                         var loud_noise_reaction__updateAt : float&;
                         var loud_noise__accumulatedNoise : float&)
  if act.curTime > loud_noise_reaction__updateAt
    loud_noise_reaction__updateAt = act.curTime + loud_noise_reaction__interval
    loud_noise__noiseVelocity -= loud_noise_reaction__interval * loud_noise__noiseVelocityFade
    loud_noise__noiseVelocity = max(-loud_noise__maxFadeVelocity, loud_noise__noiseVelocity)
    if loud_noise_reaction__wasDisturbed || loud_noise__noiseVelocity < .0
      loud_noise__prevAccumulatedNoise = loud_noise__accumulatedNoise
      loud_noise__accumulatedNoise += loud_noise__noiseVelocity

    if loud_noise__accumulatedNoise <= .0
      loud_noise__accumulatedNoise = .0
      send_net_event(eid, EventRemoveNoiseSubtemplate())

    loud_noise_reaction__wasDisturbed = false


[es(no_order, REQUIRE_NOT=deadEntity)]
def human_generate_loud_noise(act : ParallelUpdateFrameDelayed;
                              human_loud_noise__interval : float;
                              human_loud_noise__radius : float;
                              human_loud_noise__crawling : float;
                              human_loud_noise__crouching : float;
                              human_loud_noise__walking : float;
                              human_loud_noise__sprinting : float;
                              human_loud_noise__climbing : float;
                              human_loud_noise__airbornModifier : float;
                              human_net_phys__isClimbing : bool;
                              human_net_phys__isInAir : bool;
                              human_ladder__attached : bool;
                              human_net_phys : HumanActor;
                              transform : float3x4;
                              var human_loud_noise__lastIncrement : float&;
                              var human_loud_noise__lastAmount : float&;
                              var human_loud_noise__amount : float&;
                              var human_loud_noise__updateAt : float&;
                              entity_mod_values : Object const?)
  assume currentState = human_net_phys.phys.currentState
  let isMoving = (human_ladder__attached && abs(currentState.velocity.y) > 0.01 ||
                  !human_ladder__attached && length_sq(currentState.velocity) > 0.02)
  human_loud_noise__lastIncrement = .0
  if isMoving
    if currentState.isCrawl
      human_loud_noise__lastIncrement = human_loud_noise__crawling
    elif currentState.isCrouch
      human_loud_noise__lastIncrement = human_loud_noise__crouching
    elif currentState.moveState == HUMoveState.EMS_SPRINT
      human_loud_noise__lastIncrement = human_loud_noise__sprinting
    elif human_net_phys__isClimbing
      human_loud_noise__lastIncrement = human_loud_noise__climbing
    else
      let walkNoiseMult = entity_mod_values == null ? 1.0 : get_mod_value("walkNoiseMult", *entity_mod_values, 1.0)
      let walkSpeed = human_net_phys.phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_WALK)
      let moveSpeed = length(currentState.velocity)
      human_loud_noise__lastIncrement = human_loud_noise__walking * walkNoiseMult * moveSpeed / walkSpeed
    if human_net_phys__isInAir
      human_loud_noise__lastIncrement *= human_loud_noise__airbornModifier
    let humanNoiseMult = entity_mod_values == null ? 1.0 : get_mod_value("humanNoiseMult", *entity_mod_values, 1.0)
    human_loud_noise__lastIncrement *= humanNoiseMult
    human_loud_noise__amount += human_loud_noise__lastIncrement * act.dt


  if human_loud_noise__updateAt < act.curTime
    human_loud_noise__updateAt = act.curTime + human_loud_noise__interval
    human_loud_noise__lastAmount = human_loud_noise__amount
    if human_loud_noise__amount > .0
      create_loud_noise_at(transform[3], human_loud_noise__radius, human_loud_noise__amount, "human")
      human_loud_noise__amount = .0


[es(tag=server, on_disappear, REQUIRE=sleeping_monster)]
def nullify_loud_noise_on_awaken(evt : Event; var loud_noise__accumulatedNoise : float&; var loud_noise__noiseVelocity : float&)
  loud_noise__accumulatedNoise = .0
  loud_noise__noiseVelocity = .0


[es(on_event=(EventShot, CmdNetShot))]
def create_loud_noise_on_shoot(evt : Event;
                               gun__owner : EntityId;
                               loud_noise__noisePerShot = 80.0;
                               loud_noise__radius = 25.0;
                               gun_entity_mods__loudNoisePerShotMult : float = 1.0)
  query(gun__owner) <| $ [es] (transform : float3x4)
    let noisePerShot = loud_noise__noisePerShot * gun_entity_mods__loudNoisePerShotMult
    create_loud_noise_at(transform[3], loud_noise__radius, noisePerShot, "shot")


[es(tag=server)]
def create_loud_noise_on_explosion(evt : EventShellExplodedServer;
                                   loud_noise__noisePerExplosion = 250.0;
                                   loud_noise__radius = 40.0)
  create_loud_noise_at(evt.pos, loud_noise__radius, loud_noise__noisePerExplosion, "explosion")
  broadcast_net_event(EventServerTrackedLoudNoise(pos = evt.pos, radius = loud_noise__radius, amount = loud_noise__noisePerExplosion))


[es(REQUIRE=lootable_rendinst, before=used_lootable_rendinst)]
def create_loud_noise_on_used_lootable_rendinst(evt : EventDroppedLoot;
                                                transform : float3x4;
                                                loud_noise__radius : float;
                                                loud_noise__noisePerDrop : float)
  create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__noisePerDrop, "looting")


[es(on_appear, REQUIRE=rendinst_axis_rotation__enabled)]
def create_loud_noise_on_door_toggled(evt : Event;
                                      transform : float3x4;
                                      rendinst_axis_rotation__rotSpeedKoef : float;
                                      loud_noise__radius : float;
                                      loud_noise__noisePerOperation : float)
  create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__noisePerOperation * rendinst_axis_rotation__rotSpeedKoef, "door")


[es(REQUIRE=rotating_rendinst_simple_phys_processing, no_order)]
def create_loud_noise_on_door_phys_rotation(act : UpdateStageInfoAct;
                                            transform : float3x4;
                                            rotating_rendinst_simple_phys__angularVelocity : float;
                                            rendinst_axis_rotation__rotSpeed : float;
                                            loud_noise__radius : float;
                                            loud_noise__noisePerOperation : float;
                                            loud_noise__rotating_rendinst_simple_phys__interval : float;
                                            var loud_noise__rotating_rendinst_simple_phys__updateAt : float&;
                                            var loud_noise__rotating_rendinst_simple_phys__accNoise : float&)
  let maxNoisePerSecond = loud_noise__noisePerOperation
  let noiseKoef = safediv(abs(rotating_rendinst_simple_phys__angularVelocity), rendinst_axis_rotation__rotSpeed)

  let noiseThisFrame = maxNoisePerSecond * noiseKoef * act.dt
  loud_noise__rotating_rendinst_simple_phys__accNoise += noiseThisFrame

  if act.curTime < loud_noise__rotating_rendinst_simple_phys__updateAt
    return

  loud_noise__rotating_rendinst_simple_phys__updateAt = act.curTime + loud_noise__rotating_rendinst_simple_phys__interval
  create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__rotating_rendinst_simple_phys__accNoise, "door")
  loud_noise__rotating_rendinst_simple_phys__accNoise = 0.0


[es(REQUIRE=rotating_rendinst_simple_phys_processing, on_disappear)]
def create_loud_noise_on_door_phys_rotation_on_disappear(evt : Event;
                                                         transform : float3x4;
                                                         loud_noise__radius : float;
                                                         loud_noise__rotating_rendinst_simple_phys__accNoise : float)
  create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__rotating_rendinst_simple_phys__accNoise, "door")


[es]
def create_loud_noise_on_loot_pickup(evt : EventOnItemPickup; human_loud_noise__radius, human_loud_noise__noisePerLootPickup : float; transform : float3x4)
  create_loud_noise_at(transform[3], human_loud_noise__radius, human_loud_noise__noisePerLootPickup, "pickup")


[es(REQUIRE_NOT=disableUpdate)]
def create_loud_noise_on_landing(evt : CmdPostPhysUpdate;
                                 human_net_phys : HumanActor;
                                 transform : float3x4;
                                 human_loud_noise__radius : float;
                                 human_loud_noise__noisePerMpsLanding : float;
                                 var human_loud_noise__amount : float&)
  assume currentState = human_net_phys.phys.currentState
  if (uint(currentState.isInAirHistory) & 1u) == 0u && (uint(currentState.isInAirHistory) & 2u) != 0u
    let noise = human_loud_noise__noisePerMpsLanding * length(currentState.spdSummaryDiff)
    if noise > 10.0
      create_loud_noise_at(transform[3], human_loud_noise__radius, noise, "landing")
    else //there may be many small insignificant landings for which its ok to delay noise until next human_loud_noise update
      human_loud_noise__amount += noise


[es(tag=server)]
def create_loud_noise_on_reload(evt : EventWeapOnReload; human_loud_noise__radius, human_loud_noise__reload : float; transform : float3x4)
  create_loud_noise_at(transform[3], human_loud_noise__radius, human_loud_noise__reload, "reload")
  broadcast_net_event(EventServerTrackedLoudNoise(pos = transform[3], radius = human_loud_noise__radius, amount = human_loud_noise__reload))


[es(track=human_net_phys__standState, REQUIRE=human_net_phys__standState)]
def create_loud_noise_on_stance_change(evt : Event; human_loud_noise__radius, human_loud_noise__stanceChange : float; transform : float3x4)
  create_loud_noise_at(transform[3], human_loud_noise__radius, human_loud_noise__stanceChange, "stance")


[es(track=human_weap__currentGunSlot, REQUIRE=human_weap__currentGunSlot)]
def create_loud_noise_on_switch_weapon(evt : Event; human_loud_noise__radius, human_loud_noise__switchWeapon : float; transform : float3x4)
  create_loud_noise_at(transform[3], human_loud_noise__radius, human_loud_noise__switchWeapon, "switchWeapon")


[es(tag=server, before=awake_sleeping_trap)]
def create_loud_noise_on_awakens(evt : CmdAwakeSleepingMonster; isAlive : bool; loud_noise__radius, loud_noise__noisePercentPerAwake : float; transform : float3x4;
                                 loud_noise__awake : float = 0.0)
  if isAlive
    create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__awake, loud_noise__noisePercentPerAwake, loud_noise__noisePercentPerAwake, "awaken")
    broadcast_net_event(EventServerTrackedLoudNoise(pos = transform[3], radius = loud_noise__radius, amount = loud_noise__noisePercentPerAwake))


[es(on_appear)]
def create_loud_noise_on_request(evt : Event;
                                 loud_noise__name : string = "oneshot";
                                 loud_noise__radius : float;
                                 loud_noise__noise : float;
                                 loud_noise__pos : float3)
  create_loud_noise_at(loud_noise__pos, loud_noise__radius, loud_noise__noise, loud_noise__name)


[es]
def create_loud_noise_on_melee_hit(evt : EventMeleeAttackHit; loud_noise__radius, loud_noise__noisePerMeleeHit : float; transform : float3x4)
  create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__noisePerMeleeHit, "melee")


[es]
def create_loud_noise_on_projectile_hit_scene(evt : EventProjectileHitScene; loud_noise__radius, loud_noise__noisePerHit : float)
  create_loud_noise_at(evt.pos, loud_noise__radius, loud_noise__noisePerHit, "projectile hit scene")

[es]
def create_loud_noise_on_projectile_hit_someone(evt : EventProjectileIntersectEntityWithHp; loud_noise__radius, loud_noise__noisePerHit : float)
  create_loud_noise_at(evt.pos, loud_noise__radius, loud_noise__noisePerHit, "projectile hit entity")


[es(REQUIRE=throwing_stone)]
def create_loud_noise_on_stone_hit(evt : CmdPostPhysUpdate;
                                   phys_obj_net_phys : PhysObjActor;
                                   loud_noise__radius : float;
                                   loud_noise__noisePerHit : float)
  assume phys = phys_obj_net_phys.phys
  if phys.currentState.hadContact && !phys.previousState.hadContact
    let pos = float3(phys.currentState.location.P)
    create_loud_noise_at(pos, loud_noise__radius, loud_noise__noisePerHit, "stone hit")
    broadcast_net_event(EventServerTrackedLoudNoise(pos = pos, radius = loud_noise__radius, amount = loud_noise__noisePerHit))


[es(no_order)]
def update_vehicle_loud_noise(act : ParallelUpdateFrameDelayed;
                              vehicle_net_phys : VehiclePhysActor;
                              transform : float3x4;
                              loud_noise__radius : float;
                              loud_noise__noisePerRpm : float;
                              loud_noise__interval : float;
                              loud_noise__noisePerHorn : float;
                              loud_noise__hornRadius : float;
                              vehicle_horn__endTime : float;
                              var loud_noise__updateAt : float&;
                              var loud_noise__lastAmount : float&;
                              var loud_noise__accumulatedNoise : float&)
  loud_noise__accumulatedNoise += act.dt * loud_noise__noisePerRpm * vehicle_net_phys.phys.engineRPM
  if vehicle_horn__endTime > act.curTime
    loud_noise__accumulatedNoise += act.dt * loud_noise__noisePerHorn
  if act.curTime > loud_noise__updateAt
    loud_noise__updateAt = act.curTime + loud_noise__interval
    let radius = vehicle_horn__endTime > act.curTime ? loud_noise__hornRadius : loud_noise__radius
    create_loud_noise_at(transform[3], radius, loud_noise__accumulatedNoise, "vehicle")
    loud_noise__lastAmount = loud_noise__accumulatedNoise
    loud_noise__accumulatedNoise = 0.0


[es]
def create_loud_noise_on_melee_action(evt : EventMeleeAction;
                                      gun__owner : EntityId)
  query(gun__owner) <| $ [es] (loud_noise__radius : float;
                               loud_noise__noisePerMeleeAction : float;
                               transform : float3x4)
    create_loud_noise_at(transform[3], loud_noise__radius, loud_noise__noisePerMeleeAction, "melee action")


[es]
def add_on_noise_subtemplate(evt : EventAddNoiseSubtemplate; eid : EntityId; loud_noise__appendOnNoise : string)
  addSubTemplate(eid, loud_noise__appendOnNoise)

[es]
def remove_noise_subtemplate(evt : EventRemoveNoiseSubtemplate; eid : EntityId; loud_noise_reaction__addedTemplate : string)
  removeSubTemplate(eid, loud_noise_reaction__addedTemplate)


[es(tag=gameClient, no_order)]
def loud_noise_meter_fade_out(act : UpdateStageInfoAct;
                              loud_noise_meter__expFadeRatio : float;
                              loud_noise_meter__linearFadePerSecond : float;
                              var loud_noise_meter__value : float&)
  let t = exp(loud_noise_meter__expFadeRatio * act.dt)
  loud_noise_meter__value = max(.0, loud_noise_meter__value * t - loud_noise_meter__linearFadePerSecond * act.dt)


[es(tag=gameClient, on_appear)]
def reset_loud_noise_meter(evt : Event; var loud_noise_meter__value : float&)
  loud_noise_meter__value = .0


[es(tag=netClient)]
def register_serverside_loud_noise(evt : EventServerTrackedLoudNoise)
  create_loud_noise_at(evt.pos, evt.radius, evt.amount, "server-side")


[es(on_appear)]
def game_effect_create_loud_noise_on_appear(evt : Event;
                                            game_effect__attachedTo : EntityId;
                                            game_effect_create_loud_noise_on_appear__nodeName : string;
                                            game_effect_create_loud_noise_on_appear__radius : float;
                                            game_effect_create_loud_noise_on_appear__noise : float)
  assume nodeName = game_effect_create_loud_noise_on_appear__nodeName

  query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
    var entityTm = IDENT_TM
    let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, nodeName)
    if nodeId >= 0
      geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, entityTm)

      create_loud_noise_at(entityTm[3], game_effect_create_loud_noise_on_appear__radius,
                           game_effect_create_loud_noise_on_appear__noise,
                           "game_effect_create_loud_noise_on_appear")