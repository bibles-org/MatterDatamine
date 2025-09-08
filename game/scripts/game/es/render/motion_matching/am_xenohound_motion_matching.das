require ecs
require app
require math.base
require AnimV20
require DngHuman
require DagorMath
require MotionMatching
require danetlibs.renderer.includes.pufd_events


[es(tag=gameClient, REQUIRE=(mm_trajectory__customUpdate, xenohound), after=mm_update_root_orientation_es,
    before=(mm_calculate_root_offset_es, mm_trajectory_track_history))]
def xenohound_motion_matching_update_trajectory(act : ParallelUpdateFrameDelayed;
                                                animchar : AnimcharBaseComponent;
                                                mm_trajectory__linearVelocityViscosity : float;
                                                mm_trajectory__angularVelocityViscosity : float;
                                                transform : float3x4;
                                                var motion_matching__controller : MotionMatchingController;
                                                var mm_trajectory__prevPosition : float3&;
                                                var mm_trajectory__prevRotation : float4&;
                                                var mm_trajectory__currPosition : float3&;
                                                var mm_trajectory__currRotation : float4&;
                                                var mm_trajectory__linearVelocity : float3&;
                                                var mm_trajectory__angularVelocity : float3&;
                                                var mm_trajectory__wishRotation : float4&)
  // position and linear velocity update
  mm_trajectory__prevPosition = mm_trajectory__currPosition
  var animcharTm : float3x4
  animchar |> animchar_get_tm(animcharTm)
  mm_trajectory__currPosition = animcharTm[3]
  let curVelocity = (mm_trajectory__currPosition - mm_trajectory__prevPosition) / (act.dt + 0.00001f)
  mm_trajectory__linearVelocity = approach(mm_trajectory__linearVelocity, curVelocity, act.dt, mm_trajectory__linearVelocityViscosity)

  // rotation and angular velocity update
  mm_trajectory__prevRotation = mm_trajectory__currRotation
  mm_trajectory__wishRotation = normalize(quat_from_unit_arc(MotionMatching::FORWARD_DIRECTION.xyz, transform[0]))

  simple_spring_damper_exact_q(mm_trajectory__currRotation, mm_trajectory__angularVelocity,
      mm_trajectory__wishRotation, mm_trajectory__angularVelocityViscosity, act.dt)

  motion_matching__controller.rootSynchronization = false
  motion_matching__controller.rootAdjustment = true
  motion_matching__controller.rootAdjustmentVelocityRatio = 0.3
  motion_matching__controller.rootAdjustmentPosHalfLife = 0.1
  motion_matching__controller.rootAdjustmentAngVelocityRatio = 0.0
  motion_matching__controller.rootAdjustmentRotHalfLife = 0.05
  motion_matching__controller.rootClamping = true
  motion_matching__controller.rootClampingMaxDistance = 0.35
