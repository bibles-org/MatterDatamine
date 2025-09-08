require ecs
require ecs.common
require PortalRenderer
require game.es.render.portal_renderer_common


[es(tag=render, on_appear)]
def on_appear_portal_renderer(evt : Event;
                              var dynamic_portal__index : int&;
                              transform aka source_transform  : float3x4;
                              target_transform  : float3x4;
                              portal_range : float;
                              use_dense_fog : bool;
                              fog_start_dist : float)
  dynamic_portal__index = allocate_portal()
  let params = make_portal_params(portal_range, use_dense_fog, fog_start_dist)
  update_portal(dynamic_portal__index, source_transform, target_transform, params)

[es(tag=render, on_disappear)]
def on_disappear_portal_renderer(evt : Event;
                                 dynamic_portal__index : int)
  free_portal(dynamic_portal__index)

[es(tag=render, track=transform, track=target_transform)]
def move_portal_renderer(evt : Event;
                         dynamic_portal__index : int;
                         transform aka source_transform  : float3x4;
                         target_transform  : float3x4;
                         portal_range : float;
                         use_dense_fog : bool;
                         fog_start_dist : float)
  let params = make_portal_params(portal_range, use_dense_fog, fog_start_dist)
  update_portal(dynamic_portal__index, source_transform, target_transform, params)
