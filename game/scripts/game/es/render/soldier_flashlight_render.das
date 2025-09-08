require ecs
require danetlibs.renderer.includes.render_events

[es(tag=render, no_order)]
def spotlight_shadows_lods(stg : UpdateStageInfoBeforeRender; camera__active : bool; transform aka cam_transform : float3x4)
  if camera__active
    query() <| $ [es] (transform : float3x4; spot_light__shadowsDstSq : float; var spot_light__shadows : bool&)
      spot_light__shadows = distance_sq(cam_transform[3], transform[3]) < spot_light__shadowsDstSq
    query() <| $ [es] (transform : float3x4; spot_light__dynShadowsDstSq : float; var spot_light__dynamic_obj_shadows : bool&)
      spot_light__dynamic_obj_shadows = distance_sq(cam_transform[3], transform[3]) < spot_light__dynShadowsDstSq