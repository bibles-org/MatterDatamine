require ecs
require DagorMath
require AnimV20
require GeomNodeTree
require Dacoll
require game.es.level_common

def cleanup_visual_attractions(gun_eid : EntityId)
  query() <| $ [es] (eid : EntityId; flashlight_attract__visualAttractOwnerEid : EntityId)
    if flashlight_attract__visualAttractOwnerEid == gun_eid
      eid |> destroyEntity()

def create_visual_attractions(owner : EntityId; visualAttractPointTemplate : string; visualAttractPoints : Point4List)
  for it in visualAttractPoints
    createEntity(visualAttractPointTemplate) <| $(init)
      init |> set("flashlight_attract__visualAttractOffset", it.xyz)
      init |> set("flashlight_attract__visualAttractRadius", it.w)
      init |> set("flashlight_attract__visualAttractOwnerEid", owner)

[es(tag=server, on_appear, track=gun_flashlight__isOn)]
def gun_flashlight_spawn_attractions(evt : Event; eid : EntityId;
                                     gun_flashlight__isOn : bool;
                                     flashlight_attracts__visualAttractPointTemplate : string;
                                     flashlight_attracts__visualAttractPoints : Point4List)
  cleanup_visual_attractions(eid)
  if gun_flashlight__isOn
    create_visual_attractions(eid, flashlight_attracts__visualAttractPointTemplate,
                              flashlight_attracts__visualAttractPoints)


[es(tag=server, on_appear, track=attached_flashlight__isOn)]
def attached_flashlight_spawn_attractions(evt : Event; eid : EntityId;
                                          attached_flashlight__isOn : bool;
                                          flashlight_attracts__visualAttractPointTemplate : string;
                                          flashlight_attracts__visualAttractPoints : Point4List)
  cleanup_visual_attractions(eid)
  if attached_flashlight__isOn
    create_visual_attractions(eid, flashlight_attracts__visualAttractPointTemplate,
                              flashlight_attracts__visualAttractPoints)

[es(tag=server, on_disappear,
    REQUIRE=gun_flashlight__visualAttractPointTemplate)]
def flashlight_destroys_attractions(evt : Event; eid : EntityId)
  cleanup_visual_attractions(eid)

[es(tag=server, no_order)]
def flashlight_attraction_update(act : UpdateStageInfoAct;
                                 flashlight_attract__visualAttractOwnerEid : EntityId;
                                 flashlight_attract__visualAttractRadius : float;
                                 flashlight_attract__visualAttractOffset : float3;
                                 flashlight_attract__outdoorRadiusScale : float;
                                 flashlight_attract__updateInterval : float;
                                 var flashlight_attract__nextUpdate : float&;
                                 var transform aka attract_transform : float3x4&;
                                 var visual_attract_point__radius : float&)
  if act.curTime < flashlight_attract__nextUpdate
    return
  flashlight_attract__nextUpdate = act.curTime + flashlight_attract__updateInterval
  visual_attract_point__radius = 0f

  var isActive = false
  let slotAttach = query(flashlight_attract__visualAttractOwnerEid) <| $ [es] (slot_attach__slotWtmValid : bool;
                                                                               slot_attach__slotWtm : mat44f;
                                                                               animchar : AnimcharBaseComponent)
    if slot_attach__slotWtmValid
      let wOfs = geomtree_getWtmOfs(*animchar.nodeTree)
      var tm : float3x4
      tm[0] = slot_attach__slotWtm.col0.xyz
      tm[1] = slot_attach__slotWtm.col1.xyz
      tm[2] = slot_attach__slotWtm.col2.xyz
      tm[3] = slot_attach__slotWtm.col3.xyz + wOfs
      attract_transform[3] = tm * flashlight_attract__visualAttractOffset
      isActive = true

  if !slotAttach
    query(flashlight_attract__visualAttractOwnerEid) <| $ [es] (transform : float3x4)
      attract_transform[3] = transform * -flashlight_attract__visualAttractOffset.yzx
      isActive = true

  if isActive
    let isIndoor = level_common::is_pos_indoor(attract_transform[3])
    let radiusScale = isIndoor ? 1f : flashlight_attract__outdoorRadiusScale
    visual_attract_point__radius = flashlight_attract__visualAttractRadius * radiusScale
