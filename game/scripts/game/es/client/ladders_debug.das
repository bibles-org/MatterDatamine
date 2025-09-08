options no_aot
require ecs
require math.base
require DagorMath
require DagorDebug3D
require DagorSystem


[es(tag=render, no_order, REQUIRE=daeditor__selected)]
def ladder_debug(evt : UpdateStageInfoRenderDebug;
                 transform : float3x4;
                 ladder__tm : float3x4;
                 ladder__steps : int)
  let tm = transform * ladder__tm
  draw_debug_box_buffered(IDENT_BBOX, tm, E3DCOLOR(0xFF36D7FF), 1)

  let ladderHeight = length(tm[1])
  if ladder__steps > 1 && ladderHeight > 0.0
    let ladderWidth = length(tm[2])

    let up = tm[1] / ladderHeight
    let right = tm[2] / ladderWidth

    let ladderStepsDelta = ladderHeight / float(ladder__steps - 1)
    let bottomPos = tm[3] - 0.5 * ladderHeight * up
    for step in range(ladder__steps)
      let stepPos = bottomPos + (float(step) * ladderStepsDelta) * up
      draw_debug_capsule_buffered(stepPos - 0.5 * ladderWidth * right,
                                  stepPos + 0.5 * ladderWidth * right,
                                  0.03,
                                  E3DCOLOR(0xFFFF0000), 4, 1)

