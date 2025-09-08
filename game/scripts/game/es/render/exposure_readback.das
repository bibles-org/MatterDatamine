require ecs
require WorldRenderer


[es(tag=render, no_order)]
def exposure_readback(info : UpdateStageInfoAct;
                      exposure_readback__framesDelay = 4; // 4 frames is enough to free ring buffer
                      var exposure_readback__elapsedFrames : int&;
                      var exposure_readback__currectValue : float&)
  exposure_readback__elapsedFrames --
  if exposure_readback__elapsedFrames <= 0
    query() <| $ [es] (adaptation__exposure : float)
      exposure_readback__currectValue = adaptation__exposure
    exposure_readback__elapsedFrames = exposure_readback__framesDelay
