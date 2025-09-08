require ecs
require math.base
require DagorMath
require DagorSystem
require AnimV20
require danetlibs.renderer.includes.pufd_events
require MotionMatching


[es(tag=render, before=mm_trajectory_prediction)]
def am_update_mm_trajectory_wish_velocity(act : ParallelUpdateFrameDelayed;
                                          var mm_trajectory__wishLinearVelocity : float3&;
                                          navmesh_phys__wishWalkDir : float3;
                                          navmesh_phys__maxWalkSpeed : float;
                                          navmesh_phys__wishWalkSpeed : float;
                                          navmesh_phys__walkSpeedMult : float)
  let wishSpeed = navmesh_phys__maxWalkSpeed * navmesh_phys__wishWalkSpeed * navmesh_phys__walkSpeedMult
  mm_trajectory__wishLinearVelocity = navmesh_phys__wishWalkDir * wishSpeed

[es(tag=render)]
def am_mm_set_active(act : ParallelUpdateFrameDelayed;
                     var motion_matching__enabled : bool&;
                     mm_trajectory__linearVelocity : float3;
                     motion_matching__minLinearVelocityToEnableMM : float)
  motion_matching__enabled = length(mm_trajectory__linearVelocity) > motion_matching__minLinearVelocityToEnableMM //use MM only for running animation
