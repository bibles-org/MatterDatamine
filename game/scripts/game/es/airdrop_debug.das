options no_aot
require ecs
require app
require math.base
require math.random
require game.events.events_active_matter
require game.es.net_console_macro


def create_debug_airdrop(hero_eid : EntityId;
                         airdrop_spawn_above_me : bool)
  var position = float3()
  query(hero_eid) <| $ [es] (transform : float3x4)
    position = transform[3]
  var airdropMoveTo = position
  var airdropMoveFrom = position + float3(0.0, 5000.f, 0.0)
  var airdrop_template = "airdrop_container_b+airdrop_phys"
  find_query() <| $[es] (airdrop_manager__multZoneRadius : float;
                         airdrop_manager__airdropCreationHeight : float;
                         airdrop_manager__creationAirdropeAngle : float2;
                         airdrop_manager__airdropTemplate : string;
                         airdrop_manager__airdropPhysTemplate : string)
    airdrop_template := "{airdrop_manager__airdropTemplate}+{airdrop_manager__airdropPhysTemplate}"
    if airdrop_spawn_above_me
      airdropMoveFrom = position + float3(0.0, airdrop_manager__airdropCreationHeight, 0.0)
    else
      find_query() <| $[es(REQUIRE=moving_zone__movingVelocity)] (sphere_zone__radius : float;
                                                                  transform : float3x4)
        let possibleRadiusForCreateOnGround = sphere_zone__radius * airdrop_manager__multZoneRadius * rnd_float(0.0, 1.0)
        let angleFromCenterZone = rnd_float(0.0, TWOPI)
        var sin, cos : float
        sincos(angleFromCenterZone, sin, cos)
        airdropMoveTo = transform[3] + float3(cos, 0.0, sin) * possibleRadiusForCreateOnGround

        let minMaxAngleInAir = airdrop_manager__creationAirdropeAngle
        let roll = rnd_float(minMaxAngleInAir.x,  minMaxAngleInAir.y) * DEG_TO_RAD
        let yaw = rnd_float(0.0, TWOPI)
        var quat : quat
        euler_to_quat(yaw, 0.0, roll, quat)
        airdropMoveFrom = airdropMoveTo + quat_get_up(quat) * airdrop_manager__airdropCreationHeight
        return true
    return true
  createEntity(airdrop_template) <| $(init)
    init |> set("airdrop__initialPosition", airdropMoveFrom)
    init |> set("airdrop__moveTo", airdropMoveTo)
    init |> set("airdrop__startTime", get_sync_time())


[net_console_cmd(name="airdrop.immediatlyDrop", hint="Immediatly spawn airdrop")]
def console_immediatly_drop_airdrop(@net_hero hero_eid : EntityId; airdrop_spawn_above_me = true)
  create_debug_airdrop(hero_eid, airdrop_spawn_above_me)
