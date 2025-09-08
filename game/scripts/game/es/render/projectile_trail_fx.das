require ecs
require DngPhysObj
require fx


[es(tag=render, on_appear)]
def projectile_trail_fx_on_appear(evt : Event;
                                  transform : float3x4;
                                  projectile_trail_fx__flightFxTemplate : string;
                                  var projectile_trail_fx__flightFxEid : EntityId&)
  projectile_trail_fx__flightFxEid = createEntity(projectile_trail_fx__flightFxTemplate) <| $(var init)
    set(init, "transform", transform)


[es(tag=render, on_disappear)]
def projectile_trail_fx_on_disappear(evt : Event;
                                     projectile_trail_fx__flightFxEid : EntityId)
  destroyEntity(projectile_trail_fx__flightFxEid)


[es(tag=render, no_order)]
def projectile_trail_fx_on_update(info : UpdateStageInfoAct;
                                  transform : float3x4;
                                  phys_obj_net_phys : PhysObjActor;
                                  projectile_trail_fx__flightFxEid : EntityId)
  query(projectile_trail_fx__flightFxEid) <| $ [es] (var effect : TheEffect)
    let vel = normalize(phys_obj_net_phys.phys.currentState.velocity)
    effect_set_velocity(effect, vel)
    effect_set_emitter_tm(effect, transform)


[es(tag=render, on_appear)]
def projectile_trail_init_prev_pos(evt : Event;
                                   transform : float3x4;
                                   var projectile_trail_fx__previousPos : float3&)
  projectile_trail_fx__previousPos = transform[3]


[es(tag=render, no_order)]
def projectile_trail_update_prev_pos(info : UpdateStageInfoAct;
                                     transform : float3x4;
                                     var projectile_trail_fx__previousPos : float3&)
  projectile_trail_fx__previousPos = transform[3]


[es(tag=render, after=projectile_trail_update_prev_pos, REQUIRE_NOT=phys_obj_net_phys)]
def trail_fx_update_no_phys(info : UpdateStageInfoAct;
                            transform : float3x4;
                            projectile_trail_fx__previousPos : float3;
                            projectile_trail_fx__flightFxEid : EntityId)
  query(projectile_trail_fx__flightFxEid) <| $ [es] (var effect : TheEffect)
    let dist = distance(transform[3], projectile_trail_fx__previousPos)
    let speed = dist / info.dt
    var vel = float3(0.0, 0.0, 0.0)
    if speed >= 0.01
      vel = normalize(transform[3] - projectile_trail_fx__previousPos)
    effect_set_velocity(effect, vel)
    effect_set_emitter_tm(effect, transform)
