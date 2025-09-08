require ecs
require fx
require game.events.events
require math.base
require math.random
require DagorMath


[es(tag=gameClient, track=isAlive)]
def am_core_material_change(evt : Event;
                            isAlive : bool;
                            am_core__aliveMaterial : string;
                            am_core__deadMaterial : string;
                            var material : das_string)
  material := isAlive ? am_core__aliveMaterial : am_core__deadMaterial


[es(tag=render, on_appear)]
def traceable_sphere_hit_effect_init(evt : Event;
                                     traceable_sphere_hit_effect__name : string;
                                     var traceable_sphere_hit_effect__type : int&)
  traceable_sphere_hit_effect__type = get_type_by_name(traceable_sphere_hit_effect__name)


[es(tag=gameClient)]
def traceable_sphere_hit(evt : ProjectileHitInvulnerableNotification;
                         traceable_sphere_hit_effect__type : int;
                         traceable_sphere_hit_effect__important : bool;
                         traceable_sphere_hit_effect__scale : float;
                         traceable_sphere_hit_effect__fxTm : float3x4)
  var tm : float3x4
  let invHitDir = -evt.hitDir
  make_tm(dir_to_quat(invHitDir), evt.hitPos, tm)

  start_effect(traceable_sphere_hit_effect__type,
               tm,
               traceable_sphere_hit_effect__fxTm,
               traceable_sphere_hit_effect__important) <| $(var fx : AcesEffect)
    fx |> setFxScale(traceable_sphere_hit_effect__scale)


[es(tag=gameClient, on_appear)]
def explosive_am_core_fx_controller_init(evt : Event;
                                         eid : EntityId;
                                         explosive_am_core_fx_controller__fxTemplate : string;
                                         transform : float3x4;
                                         var explosive_am_core_fx_controller__fxEid : EntityId&)
  assume fxEid = explosive_am_core_fx_controller__fxEid
  fxEid = createEntity(explosive_am_core_fx_controller__fxTemplate) <| $(var init : ComponentsInitializer)
    var tm = IDENT_TM
    tm[3] = transform[3]
    init |> set("transform", tm)
    init |> set("attached__entity", eid)


[es(tag=gameClient, on_disappear)]
def explosive_am_core_fx_controller_disappear(evt : Event;
                                              explosive_am_core_fx_controller__fxEid : EntityId)
  destroyEntity(explosive_am_core_fx_controller__fxEid)


[es(tag=gameClient, before=am_core_color)]
def explosive_am_core_light_update(act : UpdateStageInfoAct;
                                   explosive_am_core_light__color : E3DCOLOR;
                                   var am_core_light__exhausted : E3DCOLOR&;
                                   var am_core_light__healthy : E3DCOLOR&)
  let lightColor = explosive_am_core_light__color
  am_core_light__exhausted = lightColor
  am_core_light__healthy = lightColor