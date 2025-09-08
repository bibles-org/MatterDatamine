require ecs
require math.base
require DagorMath


[es(tag=server, no_order, REQUIRE=agent_off_navmesh, REQUIRE_NOT=(deadEntity, nphys__noLookDir))]
def offmesh_phys_update_agent_look_dir(act : UpdateStageInfoAct;
                                       navmesh_phys__wishLookDir : float3;
                                       navmesh_phys__upDir : float3 = float3(0, 1, 0);
                                       npys_homoErectus : Tag const?;
                                       var navmesh_phys__atTime : float&;
                                       var navmesh_phys__prevTime : float&;
                                       var navmesh_phys__prevLookDir : float3&;
                                       var navmesh_phys__currentLookDir : float3&;
                                       var transform : float3x4)
  navmesh_phys__prevLookDir = navmesh_phys__currentLookDir
  let prevLookQuat = dir_and_up_to_quat(navmesh_phys__currentLookDir, navmesh_phys__upDir)
  let wishLook = approach(prevLookQuat, dir_and_up_to_quat(navmesh_phys__wishLookDir, navmesh_phys__upDir), act.dt, 0.2)
  navmesh_phys__currentLookDir = wishLook |> quat_get_forward()
  navmesh_phys__prevTime = navmesh_phys__atTime
  navmesh_phys__atTime = act.curTime

  let step = navmesh_phys__atTime - navmesh_phys__prevTime
  if step > 0f
    let k = (act.curTime - navmesh_phys__prevTime) / step
    var lookDir : quat

    if npys_homoErectus != null
      let prevLookDir = normalize(navmesh_phys__prevLookDir - navmesh_phys__upDir * dot(navmesh_phys__upDir, navmesh_phys__prevLookDir))
      let currentLookDir = normalize(navmesh_phys__currentLookDir - navmesh_phys__upDir * dot(navmesh_phys__upDir, navmesh_phys__currentLookDir))
      lookDir = slerp(dir_and_up_to_quat(prevLookDir, navmesh_phys__upDir), dir_and_up_to_quat(currentLookDir, navmesh_phys__upDir), k) |> normalize()
    else
      lookDir = slerp(dir_and_up_to_quat(navmesh_phys__prevLookDir, navmesh_phys__upDir), dir_and_up_to_quat(navmesh_phys__currentLookDir, navmesh_phys__upDir), k) |> normalize()
    make_tm(lookDir, transform[3], transform)