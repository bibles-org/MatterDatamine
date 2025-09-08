require ecs
require math
require math.base
require DagorMath
require DagorSystem
require DngNet


def apply_locomotion(var transform : float3x4&;
                     var navmesh_phys__prevLocoQuat : float4&;
                     navmesh_phys__locomotionFactor : float;
                     navmesh_phys__quatVisc : float;
                     navmesh_phys__upDir : float3;
                     acc : float3;
                     time : float)
  var tm : float3x4
  var q : quat
  if length_sq(acc) > 0.5f
    let axis = cross(float3(dot(transform[0], acc), .0, dot(transform[2], acc)), navmesh_phys__upDir) * (-1.0)
    let q0 = quat(normalize(axis), length(axis) * navmesh_phys__locomotionFactor)
    q = normalize(approach(quat(navmesh_phys__prevLocoQuat), q0, time, navmesh_phys__quatVisc))
  else
    q = normalize(approach(quat(navmesh_phys__prevLocoQuat), quat(float4(0, 0, 0, 1)), time, navmesh_phys__quatVisc))
  make_tm(q, tm)
  transform = transform * tm
  navmesh_phys__prevLocoQuat = float4(q)


[es(tag=gameClient, REQUIRE=navmeshPhys, after=navmesh_aligned_phys, REQUIRE_NOT=(deadEntity, nphys__disabled, loc_snapshots__snapshotData))]
def locomotion_for_offline_navmesh_phys(info : UpdateStageInfoAct;
                                        navmesh_phys__currentWalkVelocity : float3;
                                        navmesh_phys__accVisc : float = 0.4;
                                        navmesh_phys__quatVisc : float = 0.35;
                                        navmesh_phys__locomotionFactor : float = 0.01;
                                        navmesh_phys__upDir : float3 = float3(0, 1, 0);
                                        var navmesh_phys__prevLocoAcceleration : float3&;
                                        var navmesh_phys__prevLocoVelocity : float3&;
                                        var navmesh_phys__prevLocoQuat : float4&;
                                        var transform : float3x4&)
  var acc = (navmesh_phys__currentWalkVelocity - navmesh_phys__prevLocoVelocity) * safeinv(info.dt)
  acc = approach(navmesh_phys__prevLocoAcceleration, acc, info.dt, navmesh_phys__accVisc)
  apply_locomotion(transform, navmesh_phys__prevLocoQuat, navmesh_phys__locomotionFactor, navmesh_phys__quatVisc, navmesh_phys__upDir, acc, info.dt)
  navmesh_phys__prevLocoVelocity = navmesh_phys__currentWalkVelocity
  navmesh_phys__prevLocoAcceleration = acc


[es(tag=netClient, after=interp_loc_snapshots_es)]
def locomotion_for_online_navmesh_phys(info : UpdateStageInfoAct;
                                       var transform : float3x4&;
                                       var navmesh_phys__prevLocoAcceleration : float3&;
                                       var navmesh_phys__prevLocoVelocity : float3&;
                                       var navmesh_phys__prevLocoQuat : float4&;
                                       loc_snapshots__snapshotData : LocSnapshotsList;
                                       navmesh_phys__upDir : float3 = float3(0, 1, 0);
                                       navmesh_phys__locomotionFactor : float = 0.01;
                                       navmesh_phys__quatVisc : float = 0.35;
                                       navmesh_phys__accVisc : float = 0.4)
  let len = length(loc_snapshots__snapshotData)
  if len <= 1 || loc_snapshots__snapshotData[len - 1].blink
    if len <= 1
      navmesh_phys__prevLocoVelocity = approach(navmesh_phys__prevLocoVelocity, float3(), info.dt, navmesh_phys__accVisc)
      navmesh_phys__prevLocoAcceleration = approach(navmesh_phys__prevLocoAcceleration, float3(), info.dt, navmesh_phys__accVisc)
    var q = quat(navmesh_phys__prevLocoQuat)
    q = normalize(approach(quat(navmesh_phys__prevLocoQuat), quat(float3(), 1.f), info.dt, navmesh_phys__quatVisc))
    navmesh_phys__prevLocoQuat = float4(q)
    return

  let n = length(loc_snapshots__snapshotData)
  let begin = loc_snapshots__snapshotData[0].pos
  let end = loc_snapshots__snapshotData[n - 1].pos
  let time = loc_snapshots__snapshotData[n - 1].atTime - loc_snapshots__snapshotData[0].atTime
  let invTime = safeinv(time)
  let vel = (end - begin) * invTime
  var acc = (vel - navmesh_phys__prevLocoAcceleration) * invTime

  acc = approach(navmesh_phys__prevLocoAcceleration, acc, info.dt, navmesh_phys__accVisc)
  apply_locomotion(transform, navmesh_phys__prevLocoQuat, navmesh_phys__locomotionFactor, navmesh_phys__quatVisc, navmesh_phys__upDir, acc, info.dt)
  navmesh_phys__prevLocoVelocity = vel
  navmesh_phys__prevLocoAcceleration = acc
