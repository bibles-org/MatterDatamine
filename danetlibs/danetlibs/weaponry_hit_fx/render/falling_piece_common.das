module falling_piece_common shared

require ecs
require DagorMath
require DagorRandom
require DagorSystem
require GamePhys

let START_EPS = 0.1
let MINIMAL_TTL = 1.0
let MINIMAL_GRAVITY = 1.0

def spawn_falling_piece(effect_template : string; start_velocity, angular_speed : float; pos, norm : float3; cb : block<(var init : ComponentsInitializer) : void>)
  let piecePosition = pos + norm * START_EPS

  let upDir = float3(0.0, 1.0, 0.0)
  let normRot = quat_rotation_arc(upDir, norm)
  let initVelocity = float3(
    rnd_float(-start_velocity * 0.5, start_velocity * 0.5),
    rnd_float(start_velocity * 0.5, start_velocity),
    rnd_float(-start_velocity * 0.5, start_velocity * 0.5))
  let velocity = normRot * initVelocity
  let initDirection = normalize(velocity)
  let startOrient = quat_rotation_arc(upDir, initDirection)

  let omega = rnd_float(angular_speed * 0.2, angular_speed) * normalize(float3(gsrnd(), gsrnd(), gsrnd()))

  var transform = identity3x4()
  transform.w = piecePosition

  let ttl = 2.0 * start_velocity / max(abs(gravity()), MINIMAL_GRAVITY) + MINIMAL_TTL

  createEntity("falling_piece+{effect_template}") <| $(init)
    init |> set("transform", transform)
    init |> set("falling_piece__velocity", velocity)
    init |> set("falling_piece__max_velocity", start_velocity)

    init |> set("falling_piece__start_orient", float4(startOrient))
    init |> set("falling_piece__omega", omega)

    init |> set("falling_piece__ttl", ttl)

    cb |> invoke(init)