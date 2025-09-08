require ecs
require math
require math.base
require DagorSystem


[es(tag=gameClient, on_appear)]
def swarm_boid_fx_controller_init(evt : Event;
                                  position : float3;
                                  swarm_boid_fx_controller__effectTemplateName : string;
                                  var swarm_boid_fx_controller__effectEid : EntityId&)
  if swarm_boid_fx_controller__effectTemplateName != ""
    swarm_boid_fx_controller__effectEid = createEntity(swarm_boid_fx_controller__effectTemplateName) <| $(var init : ComponentsInitializer)
      var tm = IDENT_TM
      tm[3] = position
      init |> set("transform", tm)


[es(tag=gameClient, after=steer_es)]
def swarm_boid_fx_controller_update(act : UpdateStageInfoAct;
                                    position : float3;
                                    swarm_boid_fx_controller__effectEid : EntityId)
  query(swarm_boid_fx_controller__effectEid) <| $ [es] (var transform : float3x4)
    transform[3] = position


[es(tag=gameClient, on_disappear)]
def swarm_boid_fx_controller_disappear(evt : Event;
                                       swarm_boid_fx_controller__effectEid : EntityId)
  destroyEntity(swarm_boid_fx_controller__effectEid)