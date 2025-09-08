options no_aot
require strings
require math.color
require ecs
require ecs.safe
require ecs.soa_template
require ecs.ecs_template
require game.utils.hero
require math.base
require gameObject
require DagorConsole
require DagorDebug3D
require DagorSystem
require RendInst


[ecs_template]
struct ri_debug_draw
  ri__debugDrawDist : float = 3.0


[console_cmd(name="ri.debug_draw")]
def ri_debug_draw_cmd(dist = 3.0)
  let tmpl = "ri_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId; var ri__debugDrawDist : float&)
    if ri__debugDrawDist == dist
      destroyEntity(eid)
    else
      ri__debugDrawDist = dist
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("ri__debugDrawDist", dist)


[es(tag=render, tag=dev, no_order)]
def ri_debug_es(evt : UpdateStageInfoRenderDebug;
                ri__debugDrawDist : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform : float3x4)
    if !camera__active
      return false
    let box = BBox3(transform[3] - float3(ri__debugDrawDist), transform[3] + float3(ri__debugDrawDist))
    let oldNumCallbacks = setMaxNumRiCollisionCb(500000u)
    begin_draw_cached_debug_lines(false, false, false)
    rendinst_foreachInBox(box, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
      let resName = getRIGenResName(desc)
      let objectTypeHash = ecs_hash(resName)
      let objectTypeColor = E3DCOLOR(Color4(hsv2rgb(float3(float(objectTypeHash % 360u), 1.0, 1.0)), 1.0))

      var radius = 0.1
      if desc.isValid && desc.isRiExtra
        radius = getRIGenExtraBSphere(desc.riExtraHandle).w

      let randomPosOffset = float3(min(float(objectTypeHash % 360u) / 360.0, radius / 3.0), 0.0, 0.0)
      let pos = tm[3]
      let posEnd = pos + float3(0.0, radius / 3.0, 0.0) + randomPosOffset
      draw_cached_debug_line(pos, posEnd, objectTypeColor)
      add_debug_text_mark(posEnd, "{resName} ({desc.riExtraHandle})", -1, 0.0, objectTypeColor)
    end_draw_cached_debug_lines()
    setMaxNumRiCollisionCb(oldNumCallbacks)

    return true

enum RiDebugDrawBsphMode
  RIGEN
  RIEXTRA
  BOTH

[ecs_template]
struct ri_debug_draw_bsph
  ri__debugDrawBsphMode : int = int(RiDebugDrawBsphMode.RIEXTRA)
  ri__debugDrawBsphDist : float = 3.0

[console_cmd(name="ri.debug_draw_bsph", hint="draws the bounding spheres of rendinsts near camera. Modes: 0 - RIGEN, 1 - RIEXTRA, 2 - BOTH")]
def ri_debug_draw_bsph_cmd(mode : int = int(RiDebugDrawBsphMode.RIEXTRA);
                           dist : float = 3.0)
  if mode < 0 || mode > int(RiDebugDrawBsphMode.BOTH)
    console_print("Invalid mode. Use 0 for RIGEN, 1 for RIEXTRA, or 2 for BOTH.")
    return

  let tmpl = "ri_debug_draw_bsph"
  let exists = find_query() <| $ [es] (eid : EntityId;
                                       var ri__debugDrawBsphDist : float&;
                                       var ri__debugDrawBsphMode : int&)
    let hasChanged = ri__debugDrawBsphMode != mode || ri__debugDrawBsphDist != dist;
    if !hasChanged
      destroyEntity(eid)
    else
      ri__debugDrawBsphDist = dist
      ri__debugDrawBsphMode = mode
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("ri__debugDrawBsphDist", dist)
      init |> set("ri__debugDrawBsphMode", mode)

[es(tag=render, tag=dev, no_order)]
def ri_debug_bsph_es(info : UpdateStageInfoRenderDebug;
                     ri__debugDrawBsphDist : float;
                     ri__debugDrawBsphMode : int)
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false

    let box = BBox3(transform[3] - float3(ri__debugDrawBsphDist), transform[3] + float3(ri__debugDrawBsphDist))
    let oldNumCallbacks = setMaxNumRiCollisionCb(500000u)
    begin_draw_cached_debug_lines(true, false, false)
    rendinst_foreachInBox(box, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm), unused_argument(tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
      let shouldDrawRIGen = ri__debugDrawBsphMode == int(RiDebugDrawBsphMode.RIGEN) || ri__debugDrawBsphMode == int(RiDebugDrawBsphMode.BOTH)
      let shouldDrawRiExtra = ri__debugDrawBsphMode == int(RiDebugDrawBsphMode.RIEXTRA) || ri__debugDrawBsphMode == int(RiDebugDrawBsphMode.BOTH)
      if desc.isValid
        if desc.isRiExtra && shouldDrawRiExtra
          let bsph = getRIGenExtraBSphere(desc.riExtraHandle)
          draw_cached_debug_sphere(bsph.xyz, bsph.w, E3DCOLOR(0xFF00FF00), 24)
        elif !desc.isRiExtra && shouldDrawRIGen
          let riGenBsph = getRIGenBSphere(desc)
          set_cached_debug_lines_wtm(tm)
          draw_cached_debug_sphere(riGenBsph.xyz, riGenBsph.w, E3DCOLOR(0xFF00FF00), 24)
          set_cached_debug_lines_wtm(IDENT_TM)
    end_draw_cached_debug_lines()
    setMaxNumRiCollisionCb(oldNumCallbacks)
    return true
