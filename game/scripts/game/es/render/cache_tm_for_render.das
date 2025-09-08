require ecs


[es(tag=render, no_order)] // fix data race between Parallel update and human phys e.t.c
def cache_tm_for_ui_render(info : UpdateStageInfoAct;
                           transform : float3x4;
                           var transform_lastFrame : float3x4)
  transform_lastFrame = transform
