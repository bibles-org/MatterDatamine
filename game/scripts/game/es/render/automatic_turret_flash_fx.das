require ecs
require fx
require AnimV20
require GeomNodeTree
require math.base
require game.events.events_game
require DagorRandom


[es(tag=render, on_appear)]
def automatic_turret_init_flash_fx(evt : Event; animchar : AnimcharBaseComponent; turret__flashFxNodeName : string; turret__flashFxTemplate : string;
                                   var turret__flashFxNodeIdx : int&)
  turret__flashFxNodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, turret__flashFxNodeName)
  let fxType = get_type_by_name(turret__flashFxTemplate)
  prefetch_effect(fxType)


[es(tag=render, no_order)]
def automatic_turret_gun_flash_effect_destroyer_es(info : UpdateStageInfoAct; eid : EntityId; var turret_gun_flash_effect__lifetime : float&)
  turret_gun_flash_effect__lifetime -= info.dt
  if turret_gun_flash_effect__lifetime <= 0.0
    destroyEntity(eid)


[es(tag=render)]
def automatic_turret_gun_flash_fx_inserter_es(evt : CmdNetShot; turret__flashFxTemplate : string; animchar : AnimcharBaseComponent;
                                              turret__flashFxNodeIdx : int; turret__flashFxScaleRng : float2)
  if turret__flashFxNodeIdx < 0
    return

  let flashEid = createEntitySync(turret__flashFxTemplate) <| $(var init : ComponentsInitializer)
    var tm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, turret__flashFxNodeIdx, tm)
    tm = tm * scale_tm(rnd_float(turret__flashFxScaleRng.x, turret__flashFxScaleRng.y))
    set(init, "transform", tm)
  query(flashEid) <| $ [es] (effect__name : string; var turret_gun_flash_effect__lifetime : float&)
    let fxId = get_type_by_name(effect__name)
    turret_gun_flash_effect__lifetime = get_effect_life_time(fxId)