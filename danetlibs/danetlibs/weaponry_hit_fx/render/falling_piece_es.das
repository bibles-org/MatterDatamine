require ecs
require Dacoll
require GamePhys
require DagorMath
require DagorRandom
require danetlibs.weaponry_hit_fx.render.falling_piece_common
require DaWeapons
require DaWeaponProps
require DagorSystem


[es(tag=render, no_order)]
def falling_piece_move_es(info : UpdateStageInfoAct;
                          eid : EntityId;
                          falling_piece__max_velocity : float;
                          falling_piece__omega : float3;
                          falling_piece__start_orient : float4&;
                          falling_piece__ttl : float;
                          var falling_piece__elapsed_time : float&;
                          var transform : float3x4&;
                          var falling_piece__velocity : float3&)

  let acc = float3(0.0, -gravity(), 0.0)
  let delta_velocity = acc * info.dt

  var nextVelocity = falling_piece__velocity + delta_velocity
  if length(nextVelocity) > falling_piece__max_velocity
    nextVelocity = normalize(nextVelocity) * falling_piece__max_velocity

  let avg_velocity = (falling_piece__velocity + nextVelocity) * 0.5
  falling_piece__velocity = nextVelocity

  let initialPos = transform[3]
  let deltaPos = avg_velocity * info.dt
  let newPos = initialPos + deltaPos

  let dir = normalize(avg_velocity)
  if rayhit_normalized(initialPos, dir, length(deltaPos), ETF_DEFAULT, -1)
    destroyEntity(eid)
    return

  falling_piece__elapsed_time += info.dt
  let orientInc = falling_piece__omega * falling_piece__elapsed_time
  let orient = quat(orientInc, length(orientInc)) * quat(falling_piece__start_orient)
  make_tm(orient, transform)

  transform[3] = newPos

  if falling_piece__elapsed_time > falling_piece__ttl
    destroyEntity(eid)