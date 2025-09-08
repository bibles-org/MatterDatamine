require ecs
require app
require DngNet
require RendInst
require Grid
require CollRes
require math.base
require DagorMath
require game.utils.team
require game.es.riextra_common
require game.events.events_game
require game.events.vehicle_events
require game.utils.sound_utils


[es(on_disappear)]
def am_core_damage_sphere_controller_disappear(evt : Event;
                                               am_core_damage_sphere_controller__damageSphereEid : EntityId)
  destroyEntity(am_core_damage_sphere_controller__damageSphereEid)


[es(on_disappear, REQUIRE=am_core_damage_sphere)]
def am_core_damage_sphere_disappear(evt : Event;
                                    sphere_zone__radius : float;
                                    transform : float3x4;
                                    am_core_damage_sphere__humanInsideTemplate : string)
  let damageSphere = BSphere3(transform[3], sphere_zone__radius * 2.0) // to hannle max humans around
  for_each_entity_in_grid(ecs_hash("humans"), damageSphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId)
    human_eid |> removeSubTemplate(am_core_damage_sphere__humanInsideTemplate)


[es(no_order, REQUIRE=am_core_damage_sphere)]
def am_core_damage_sphere_update_transform(info : UpdateStageInfoAct;
                                           am_core_damage_sphere__ownerEid : EntityId;
                                           var transform aka damage_shield_transform : float3x4)
  query(am_core_damage_sphere__ownerEid) <| $ [es] (transform aka owner_shield_transform : float3x4;
                                                    am_core_damage_sphere_controller__attached : bool = true)
    if am_core_damage_sphere_controller__attached
      damage_shield_transform[3] = owner_shield_transform[3]


[es(track=am_core_damage_sphere_controller__damageSphereEnabled, on_appear)]
def am_core_damage_sphere_track_enabled(evt : Event;
                                        eid : EntityId;
                                        transform : float3x4;
                                        am_core_damage_sphere_controller__damageSphereTemplate : string;
                                        am_core_damage_sphere_controller__damageSphereEnabled : bool;
                                        var am_core_damage_sphere_controller__damageSphereEid : EntityId&)
  assume enabled = am_core_damage_sphere_controller__damageSphereEnabled
  assume damageSphereTemplate = am_core_damage_sphere_controller__damageSphereTemplate

  if enabled && !doesEntityExist(am_core_damage_sphere_controller__damageSphereEid)
    am_core_damage_sphere_controller__damageSphereEid = createEntity(damageSphereTemplate) <| $(init)
      var tm = IDENT_TM
      tm[3] = transform[3]
      init |> set("am_core_damage_sphere__ownerEid", eid)
      init |> set("transform", tm)
  elif !enabled && am_core_damage_sphere_controller__damageSphereEid != INVALID_ENTITY_ID
    destroyEntity(am_core_damage_sphere_controller__damageSphereEid)
    am_core_damage_sphere_controller__damageSphereEid = INVALID_ENTITY_ID


def check_spheres_intersection(sphere0 : BSphere3;
                               sphere1 : BSphere3)
  let dist = distance(sphere0.c, sphere1.c)
  let radSum = sphere0.r + sphere1.r
  return dist < radSum && dist > abs(sphere1.r - sphere0.r)


// [es(tag=server, no_order)]
// def am_core_damage_sphere_update_server(act : UpdateStageInfoAct;
//                                         //am_core_damage_sphere__ownerEid : EntityId;
//                                         transform aka sphere_transform : float3x4;
//                                         sphere_zone__radius : float;
//                                         am_core_damage_sphere__updateInterval : float;
//                                         am_core_damage_sphere__pushForce : float;
//                                         am_core_damage_sphere__pushForceEffectName : string;
//                                         //am_core_damage_sphere__damagePerTick : float2;
//                                         var am_core_damage_sphere__nextUpdateAt : float&)
//   if am_core_damage_sphere__nextUpdateAt > act.curTime
//     return

//   am_core_damage_sphere__nextUpdateAt = act.curTime + am_core_damage_sphere__updateInterval

//   let damageSphere = BSphere3(sphere_transform[3], sphere_zone__radius)
//   for_each_entity_in_grid(ecs_hash("humans"), damageSphere, GridEntCheck BOUNDING) <| $(human_eid : EntityId)
//     query(human_eid) <| $ [es] (transform aka human_transform : float3x4;
//                                 collres : CollisionResource)
//       let humanBSphereLS_R = collres.boundingSphereRad
//       let c = human_transform * collres.boundingSphereCenter
//       let humanBSphereWS = BSphere3(c, humanBSphereLS_R*2.0)
//       if check_spheres_intersection(damageSphere, humanBSphereWS)
//         // let damageDesc = DamageDesc(DamageType DM_FIRE, rnd_float(am_core_damage_sphere__damagePerTick), sphere_transform[3])
//         // damage_entity(human_eid, am_core_damage_sphere__ownerEid, damageDesc)
//         sendEvent(human_eid, [[CmdPushPhys vel=normalize(sphere_transform[3] - human_transform[3]) * am_core_damage_sphere__pushForce, push_immunity=0.0]])
//         createEntity(am_core_damage_sphere__pushForceEffectName) <| $(var init)
//           var tm := human_transform
//           tm[3] += tm[1] * humanBSphereLS_R * 1.5 // hand height
//           set(init, "transform", tm)
//         broadcast_net_sound(human_eid, "use_repairkit", c)


[es(tag=server)]
def am_core_damage_sphere_update_server_enter(evt : EventZoneEnter;
                                              transform aka sphere_transform : float3x4;
                                              am_core_damage_sphere__pushForce : float;
                                              am_core_damage_sphere__pushForceVehicle : float;
                                              am_core_damage_sphere__humanInsideTemplate : das_string const?)
  query(evt.visitorEid) <| $ [es] (transform aka entity_transform : float3x4; vehicle : Tag const?)
    let dir = normalize(sphere_transform[3] - entity_transform[3])
    if vehicle != null
      sendEvent(evt.visitorEid, CmdVehiclePushPhys(
        energyScaledDir = dir * am_core_damage_sphere__pushForceVehicle,
        arm = sphere_transform[3],
        duration = 0.0
      ))
    else
      sendEvent(evt.visitorEid, CmdPushPhys(vel = dir * am_core_damage_sphere__pushForce, push_immunity = 0.0))
      if am_core_damage_sphere__humanInsideTemplate != null
        evt.visitorEid |> addSubTemplate(string(*am_core_damage_sphere__humanInsideTemplate))


[es(tag=server)]
def am_core_damage_sphere_update_server_exit(evt : EventZoneLeave;
                                             eid : EntityId;
                                             transform aka sphere_transform : float3x4;
                                             am_core_damage_sphere__pushForce : float;
                                             am_core_damage_sphere__pushForceEffectName : das_string const?;
                                             am_core_damage_sphere__humanInsideTemplate : das_string const?;
                                             am_core_damage_sphere__heroCanExit : Tag const?)
  query(evt.visitorEid) <| $ [es] (collres : CollisionResource; transform aka human_transform : float3x4)
    if am_core_damage_sphere__heroCanExit == null
      let dir = normalize(sphere_transform[3] - human_transform[3])
      sendEvent(evt.visitorEid, CmdPushPhys(vel = dir * am_core_damage_sphere__pushForce * 2.0, push_immunity = 0.0))
      if am_core_damage_sphere__pushForceEffectName != null
        createEntity(string(*am_core_damage_sphere__pushForceEffectName)) <| $(var init)
          var tm := human_transform
          tm[3] += collres.boundingBox.center // hand height
          set(init, "transform", tm)
        broadcast_net_sound(eid, "hit", human_transform[3])
    if am_core_damage_sphere__humanInsideTemplate != null
      evt.visitorEid |> removeSubTemplate(string(*am_core_damage_sphere__humanInsideTemplate))


[es(tag=server)]
def am_core_damage_sphere_launch_projectile_inside(evt : CmdLaunchProjectile;
                                                   eid : EntityId;
                                                   human_in_zero_gravity_field__shootPushForce : float)
  let forceDir = -normalize(evt.launchDesc.vel)
  sendEvent(eid, CmdPushPhys(vel = forceDir * human_in_zero_gravity_field__shootPushForce, push_immunity = 0.0))


[es(tag=server)]
def am_core_explosion_sphere_server_enter(evt : EventZoneEnter;
                                          eid : EntityId;
                                          am_core_explosion_sphere__explosionTemplate : string)
  createEntity(am_core_explosion_sphere__explosionTemplate) <| $(var init)
    init |> set("game_effect__ownerEid", eid)


[es(tag=server, on_appear)]
def am_core_explosion_sphere_server_explode(evt : Event;
                                            eid, am_core_damage_sphere__ownerEid : EntityId;
                                            transform : float3x4;
                                            team : int = TEAM_UNASSIGNED;
                                            am_core_explosion_sphere_explosion__pushForce : float;
                                            am_core_explosion_sphere_explosion__pushForceVehicle : float;
                                            am_core_explosion_sphere_explosion__pushUpForce : float;
                                            am_core_explosion_sphere_explosion__riDmgRadius : float;
                                            am_core_explosion_sphere_explosion__riDmgNearFar : float2;
                                            sphere_zone__radius : float)
  let influenceSphere = BSphere3(transform[3], sphere_zone__radius)
  for_each_entity_in_grid(ecs_hash("humans"), influenceSphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId; human_pos : float3)
    let dir = normalize(x0z(human_pos - transform[3]) + float3(0.0, am_core_explosion_sphere_explosion__pushUpForce, 0.0))
    sendEvent(human_eid, CmdPushPhys(vel = dir * am_core_explosion_sphere_explosion__pushForce, push_immunity = 0.0))
  for_each_entity_in_grid(ecs_hash("vehicles"), influenceSphere, GridEntCheck.BOUNDING) <| $(vehicle_eid : EntityId; vehicle_pos : float3)
    let dir = normalize(x0z(vehicle_pos - transform[3]) + float3(0.0, am_core_explosion_sphere_explosion__pushUpForce, 0.0))
    sendEvent(vehicle_eid, CmdVehiclePushPhys(
      energyScaledDir = dir * am_core_explosion_sphere_explosion__pushForceVehicle,
      arm = transform[3],
      duration = 0.0
    ))

  damage_ri_in_sphere(transform[3],
                      am_core_explosion_sphere_explosion__riDmgRadius,
                      am_core_explosion_sphere_explosion__riDmgNearFar,
                      get_sync_time(), !is_true_net_server(),
                      $(riex_handle : riex_handle_t){ riex_set_offender(riex_handle, eid); },
                      $(riex_handle : riex_handle_t){ return riex_should_damage(eid, team, riex_handle); })

  destroyEntity(am_core_damage_sphere__ownerEid)
  destroyEntity(eid)
