require ecs
require WorldRenderer
require CollRes
require RendInst
require DagorMath


[es(tag=gameClient, on_appear, REQUIRE_NOT=base_build_mode_controller_preview)]
def remove_grass_on_construction_part_ri_appear(evt : Event;
                                                construction_part__controller : EntityId;
                                                construction_part__localTransform : float3x4;
                                                ri_extra : RiExtraComponent)
  query(construction_part__controller) <| $ [es(REQUIRE_NOT=base_build_mode_controller_preview)] (transform : float3x4)
    let bbox = construction_part__localTransform * getRIGenBBox(RendInstDesc(ri_extra.handle))
    let sphere = BSphere3(bbox)
    let tm = transform * construction_part__localTransform
    let pos = tm[3]
    erase_grass(pos, sphere.r)


[es(tag=gameClient, on_appear, REQUIRE_NOT=base_build_mode_controller_preview)]
def remove_grass_on_construction_part_collres_appear(evt : Event;
                                                     construction_part__controller : EntityId;
                                                     construction_part__localTransform : float3x4;
                                                     collres : CollisionResource)
  query(construction_part__controller) <| $ [es(REQUIRE_NOT=base_build_mode_controller_preview)] (transform : float3x4)
    let bbox = construction_part__localTransform * BBox3(collres.vFullBBox)
    let sphere = BSphere3(bbox)
    let tm = transform * construction_part__localTransform
    let pos = tm[3]
    erase_grass(pos, sphere.r)
