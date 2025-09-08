require ecs
require math.random
require game.events.events
require math.base
require game.es.math_common
require DagorMath
require DagorRandom
require PhysObj
require DngPhysObj
require DngHuman


def rnd_dir3(var seed : int&)
  let phi = 2.0 * PI * _rnd_float(seed, 0.0, 1.0)
  let theta = acos(rnd_float(-1.0, 1.0))
  return float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))


[es(tag=server, after=phys_obj_phys_es, before=after_net_phys_sync, REQUIRE=disableUpdate)]
def phys_obj_enable_update_check(info : UpdateStageInfoAct;
                                 eid : EntityId;
                                 phys_obj_net_phys : PhysObjActor)
  if !phys_obj_net_phys.phys.currentState.isSleep
    removeSubTemplate(eid, "disable_update")


[es(tag=server, after=phys_obj_phys_es, before=after_net_phys_sync, REQUIRE_NOT=disableUpdate)]
def phys_obj_disable_update_check(info : UpdateStageInfoAct;
                                  eid : EntityId;
                                  phys_obj_net_phys : PhysObjActor)
  if phys_obj_net_phys.phys.currentState.isSleep
    addSubTemplate(eid, "disable_update")


[es(on_appear)]
def phys_obj_init_impulse(evt : Event;
                          eid : EntityId;
                          phys_obj_init_impulse__velocityRng : float2;
                          phys_obj_init_impulse__omegaRng : float2;
                          var phys_obj_net_phys : PhysObjActor)
  var seed = int(uint(eid))

  let velocityValue = _rnd_float(seed, phys_obj_init_impulse__velocityRng)
  let omegaValue = _rnd_float(seed, phys_obj_init_impulse__omegaRng)
  let velocityDir = rnd_dir3(seed)
  let omegaDir = rnd_dir3(seed)

  phys_obj_net_phys.phys.currentState.velocity += velocityValue * velocityDir
  phys_obj_net_phys.phys.currentState.omega += omegaValue * omegaDir


[es]
def phys_obj_falling_to_side_update(act : CmdPostPhysUpdate;
                                    phys_obj__fallingToSideLerpKoef : float = 4.0;
                                    phys_obj__fallingToSideAxisIdx : int;
                                    transform : float3x4;
                                    var phys_obj_net_phys : PhysObjActor)
  assume currentState = phys_obj_net_phys.phys.currentState

  if !currentState.hadContact
    return

  let axis0Idx = phys_obj__fallingToSideAxisIdx
  let axis1Idx = (axis0Idx + 1) % 3
  let axis2Idx = (axis0Idx + 2) % 3

  let fallingToSideCurrentAxis = transform[axis0Idx]
  var fallingToSideAxisSign = sign(dot(fallingToSideCurrentAxis, currentState.gravDirection))
  if is_equal_float(fallingToSideAxisSign, 0.0)
    fallingToSideAxisSign = 1.0
  let fallingToSideTargetAxis = fallingToSideAxisSign * currentState.gravDirection

  var targetRotTm : float3x4
  targetRotTm[axis0Idx] = fallingToSideTargetAxis
  targetRotTm[axis1Idx] = get_perpendicular_closest_to_axis(fallingToSideTargetAxis, transform[axis1Idx])
  targetRotTm[axis2Idx] = cross(targetRotTm[axis0Idx], targetRotTm[axis1Idx])

  let q = slerp(currentState.location.O.quat,
                DagorMath::quat(targetRotTm),
                act.dt * phys_obj__fallingToSideLerpKoef)
  currentState.location.O |> orient_setQuat(q)