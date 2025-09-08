require ecs
require DagorMathUtils
require DngHuman
require game.events.events


[es(REQUIRE=hero, tag=input, after=human_input_es, before=before_net_phys_sync)]
def lock_camera_on_downed(info : UpdateStageUpdateInput;
                          isDowned : bool;
                          downedMaxAngles : float2;
                          human_net_phys__prevVertDir : float3;
                          human_net_phys__prevRootDir : float3;
                          var human_net_phys : HumanActor;
                          var human_input__aimAngle : float2&)
  if !isDowned
    return

  let maxAngles = float4(
    downedMaxAngles,
    downedMaxAngles
  )

  let sideDir = normalize(cross(human_net_phys__prevRootDir, human_net_phys.phys.currentState.vertDirection))
  let bodyDir3d = relative_2d_dir_to_absolute_3d_dir(human_net_phys.phys.currentState.bodyOrientDir, human_net_phys__prevRootDir, sideDir)
  let wishAngles = basis_aware_clamp_angles_by_dir(human_input__aimAngle, maxAngles, bodyDir3d, human_net_phys__prevVertDir, human_net_phys__prevRootDir)

  let wishDir = basis_aware_angles_to_dir(wishAngles, human_net_phys__prevVertDir, human_net_phys__prevRootDir)
  human_control_state_set_wish_look_dir(human_net_phys.phys.producedCT, wishDir)
  human_control_state_set_wish_shoot_dir(human_net_phys.phys.producedCT, wishDir)
  human_input__aimAngle = wishAngles