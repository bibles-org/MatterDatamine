require ecs
require soundEvent
require soundSystem
require Ballistics
require BallisticsProps
require math.base
require DagorMath
require DaWeapons
require strings
require game.es.camera_common
require weapon_sounds.modules.weapon_sounds_events


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(trace_scene_after_update_projectile_es, sound_begin_update_es), before=sound_end_update_es)]
def projectile_wiz_sound(evt : Event)

  query() <| $ [es] (wiz_sound_settings__caliberToDist : float4;
                     wiz_sound_settings__dirThresholds : float2)

    let listener = get_listener_pos()
    find_query() <| $ [es] (ownerEid : EntityId;
                            launch_desc : LaunchDesc;
                            projectile__prevPos : float3;
                            projectile_ballistics : ProjectileBallistics;
                            projectile_ballistics_props : ProjectileProps;
                            projectile_trace_info__dir : float3;
                            projectile__stopped : bool = false;
                            projectile__intersectionCount : int = 0;
                            projectile_sound__wizSound = "impact/wiz";
                            projectile_sound__maxIntersectionCount = 0)
      if !projectile__stopped && !has(ownerEid, "hero") && projectile__intersectionCount <= projectile_sound__maxIntersectionCount
        assume dir = projectile_trace_info__dir
        assume pos = projectile_ballistics.state.pos
        assume prevPos = projectile__prevPos
        let closestPointOnDir = pos + dir * dot(listener - pos, dir)
        if dot(prevPos - closestPointOnDir, dir) <= 0. && dot(pos - closestPointOnDir, dir) > 0.
          if length_sq(closestPointOnDir - listener) < square(cvt(projectile_ballistics_props.caliber, wiz_sound_settings__caliberToDist.x, wiz_sound_settings__caliberToDist.y, wiz_sound_settings__caliberToDist.z, wiz_sound_settings__caliberToDist.w))

            // !((launchPos is in front) && (fly dir is perpendicular to view))
            let launchDir = normalize(launch_desc.tm[3] - listener)
            let viewDir = get_cam_itm()[2]
            if dot(launchDir, viewDir) > wiz_sound_settings__dirThresholds.x && abs(dot(dir, viewDir)) < wiz_sound_settings__dirThresholds.y
              return false

            var handle = play(projectile_sound__wizSound, closestPointOnDir)
            set_var(handle, "cal", projectile_ballistics_props.caliber)
            abandon(handle)
            sendEvent(ownerEid, EventOnWizSound(pos = closestPointOnDir))
            return true
      return false
