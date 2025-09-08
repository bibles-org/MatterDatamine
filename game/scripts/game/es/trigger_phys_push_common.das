module trigger_phys_push_common shared

require ecs
require app
require game.events.events
require game.vehicle
require game.events.events_game
require game.utils.team
require math.base
require DagorMath
require DngDm
require game.events.vehicle_events
require daslib/array_boost


def push_entity(eid : EntityId;
                beh_tree__enabled : bool;
                dir : float3;
                add_rot : quat;
                radius : float;
                speed : float;
                distance_power : float;
                distance_power_scale_limits : float2;
                enemy_effect_template : das_string const?;
                enemy_effect_template_ttl : float;
                immunity_amount : float;
                hit_tag_power_mult : float;
                ai_distance_power_mult : float)
  let invRadius = safeinv(radius)
  let dirLen = length(dir)
  let dirN = dir * safeinv(dirLen)
  assume limits = distance_power_scale_limits
  var power = clamp(pow(1.0 - dirLen * invRadius, distance_power), limits.x, limits.y)
  if beh_tree__enabled
    power *= ai_distance_power_mult
  let pushDir = add_rot * dirN
  let vel = pushDir * speed * power
  let push_immunity = immunity_amount * speed
  sendEvent(eid, CmdPushPhys(vel = vel, push_immunity = push_immunity))

  if hit_tag_power_mult > 0.0
    sendEventImmediate(eid, CmdHumanHitTagging(powerMult = hit_tag_power_mult))

  if enemy_effect_template != null
    createEntity((*enemy_effect_template) |> string()) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", eid)
      init |> set("game_effect__destroyAt", get_sync_time() + enemy_effect_template_ttl)


def push_around(transform : float3x4;
                radius : float;
                speed : float;
                distance_power : float;
                distance_power_scale_limits : float2;
                pitch : float;
                enemy_effect_template : das_string const?;
                vehicle_energy_scale : float;
                vehicle_point_offset : float3;
                enemy_effect_template_ttl : float;
                enemy_damage : float;
                immunity_amount : float;
                hit_tag_power_mult : float;
                ai_distance_power_mult : float;
                main_actor_eid : EntityId)
  let centerPos = transform[3]
  let radiusSq = radius * radius
  var quatRes : quat
  euler_to_quat(0.0, deg_to_rad(pitch), 0.0, quatRes)

  query() <| $ [es(REQUIRE=human_net_phys)] (eid : EntityId;
                                             transform : float3x4;
                                             team : int = int(TEAM_UNASSIGNED);
                                             isInVehicle : bool = false;
                                             beh_tree__enabled : bool = false;
                                             game_effect__invisible : bool = false)
    if isInVehicle
      return

    push_human_around(transform, centerPos,
                      eid, main_actor_eid,
                      quatRes,
                      radius, speed, distance_power,
                      distance_power_scale_limits,
                      enemy_effect_template,
                      enemy_effect_template_ttl,
                      immunity_amount, hit_tag_power_mult, ai_distance_power_mult,
                      enemy_damage,
                      team,
                      beh_tree__enabled, game_effect__invisible)

  query() <| $ [es(REQUIRE=npysPushable)] (eid : EntityId;
                                           transform : float3x4;
                                           team : int = int(TEAM_UNASSIGNED);
                                           isInVehicle : bool = false;
                                           beh_tree__enabled : bool = false;
                                           game_effect__invisible : bool = false)
    if isInVehicle
      return

    push_human_around(transform, centerPos,
                      eid, main_actor_eid,
                      quatRes,
                      radius, speed, distance_power,
                      distance_power_scale_limits,
                      enemy_effect_template,
                      enemy_effect_template_ttl,
                      immunity_amount, hit_tag_power_mult, ai_distance_power_mult,
                      enemy_damage,
                      team,
                      beh_tree__enabled, game_effect__invisible)

  query() <| $ [es(REQUIRE=phys_obj_net_phys)] (eid : EntityId;
                                                transform : float3x4)
    let dir = transform[3] - centerPos
    if length_sq(dir) < radiusSq
      push_entity(eid, false, dir, quatRes, radius, speed,
                  distance_power, distance_power_scale_limits,
                  null, enemy_effect_template_ttl,
                  immunity_amount, 0.0, ai_distance_power_mult)

  let orig_tm = transform
  query() <| $ [es] (eid : EntityId;
                     transform : float3x4;
                     vehicle_net_phys : VehiclePhysActor)
    let dir = transform[3] - centerPos

    if length_sq(dir) < radiusSq && empty(vehicle_net_phys.phys.explosionDamageImpulses)
      var originateTm = orig_tm
      originateTm[3] = orig_tm * vehicle_point_offset
      let pushDir = normalize(transform[3] - originateTm[3])
      let energyScale = cvt(length(dir), 0.0, radius, vehicle_energy_scale, 0.0)
      let energyScaledDir = pushDir * energyScale
      let arm = transform[3] - normalize(dir)
      sendEvent(eid, CmdVehiclePushPhys(energyScaledDir = energyScaledDir, arm = arm, duration = 0.0))


def push_human_around(transform : float3x4;
                      centerPos : float3;
                      eid, main_actor_eid : EntityId;
                      quatRes : quat;
                      radius, speed, distance_power : float;
                      distance_power_scale_limits : float2;
                      enemy_effect_template : das_string const?;
                      enemy_effect_template_ttl : float;
                      immunity_amount, hit_tag_power_mult, ai_distance_power_mult : float;
                      enemy_damage : float;
                      team : int;
                      beh_tree__enabled, game_effect__invisible : bool)
  if game_effect__invisible
    return

  let dir = transform[3] - centerPos
  let dirLenSq = length_sq(dir)

  if main_actor_eid != eid && dirLenSq < square(radius)
    push_entity(eid, beh_tree__enabled, dir, quatRes, radius, speed,
                distance_power, distance_power_scale_limits,
                enemy_effect_template, enemy_effect_template_ttl,
                immunity_amount, hit_tag_power_mult, ai_distance_power_mult)

    if enemy_damage > FLT_EPSILON
      let mainActorTeam = get_int(main_actor_eid, "team") ?? int(TEAM_UNASSIGNED)
      if !is_teams_friendly(team, mainActorTeam)
        var power = pow(1.0 - sqrt(dirLenSq) * safeinv(radius), distance_power)
        power = clamp(power, distance_power_scale_limits.x, distance_power_scale_limits.y)
        let dmg = enemy_damage * power
        if dmg > FLT_EPSILON
          let damage = DamageDesc(DamageType.DM_EXPLOSION, dmg, transform[3])
          damage_entity(eid, main_actor_eid, damage)