require ecs
require app
require math.base
require DagorSystem
require DagorMath
require game.es.am_core_warrior_common


def calculate_basis(norm : float3;
                    var axis0 : float3&;
                    var axis1 : float3&)
  let noise = abs(dot(norm, float3(1, 0, 0))) < 0.5 ? float3(1, 0, 0) : float3(0, 1, 0)
  axis0 = cross(norm, norm + noise)
  axis1 = cross(norm, axis0)


[es(tag=gameClient, on_appear)]
def am_core_warrior_attack_visual_controller_init(evt : Event;
                                                  eid : EntityId;
                                                  transform : float3x4;
                                                  am_core_warrior_attack_visual_controller__diskTemplate : string;
                                                  am_core_warrior_attack_visual_controller__ringTemplate : string;
                                                  var am_core_warrior_attack_visual_controller__diskEid : EntityId&;
                                                  var am_core_warrior_attack_visual_controller__ringEid : EntityId&)
  assume diskTemplate = am_core_warrior_attack_visual_controller__diskTemplate
  assume ringTemplate = am_core_warrior_attack_visual_controller__ringTemplate
  assume diskEid = am_core_warrior_attack_visual_controller__diskEid
  assume ringEid = am_core_warrior_attack_visual_controller__ringEid
  if diskTemplate != ""
    diskEid = createEntity(diskTemplate) <| $(var init : ComponentsInitializer)
      init |> set("transform", transform)
      init |> set("ownerEid", eid)
      init |> set("am_core_warrior_radial_plane__scale", 0.0)
  if ringTemplate != ""
    ringEid = createEntity(ringTemplate) <| $(var init : ComponentsInitializer)
      init |> set("transform", transform)
      init |> set("ownerEid", eid)
      init |> set("am_core_warrior_radial_plane__scale", 0.0)


[es(tag=gameClient, on_disappear)]
def am_core_warrior_attack_visual_controller_disappear(evt : Event;
                                                       var am_core_warrior_attack_visual_controller__diskEid : EntityId&;
                                                       var am_core_warrior_attack_visual_controller__ringEid : EntityId&)
  destroyEntity(am_core_warrior_attack_visual_controller__diskEid)
  am_core_warrior_attack_visual_controller__diskEid = INVALID_ENTITY_ID
  destroyEntity(am_core_warrior_attack_visual_controller__ringEid)
  am_core_warrior_attack_visual_controller__ringEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_appear)]
def am_core_warrior_radial_plane_init(evt : Event;
                                      transform : float3x4;
                                      var am_core_warrior_radial_plane__rot : float4&)
  am_core_warrior_radial_plane__rot = float4(DagorMath::quat(transform))


[es(tag=gameClient, REQUIRE=am_core_warrior_radial_plane, after=(oscillate_core_warriror, am_warrior_spinning))]
def am_core_warrior_radial_plane_update(act : UpdateStageInfoAct;
                                        ownerEid : EntityId;
                                        am_core_warrior_radial_plane__scale : float;
                                        var am_core_warrior_radial_plane__rot : float4&;
                                        var transform aka plane_transform : float3x4)
  query(ownerEid) <| $ [es] (transform aka warrior_transform : float3x4;
                             am_core_warrior__normal : float3)
    var tm : float3x4
    tm[1] = am_core_warrior__normal
    calculate_basis(tm[1], tm[0], tm[2])
    let targetRot = float4(DagorMath::quat(tm))

    let curRot = slerp(quat(am_core_warrior_radial_plane__rot), quat(targetRot), act.dt * 2.0)
    am_core_warrior_radial_plane__rot = float4(curRot)
    make_tm(curRot, warrior_transform[3], tm)

    plane_transform = tm * scale_tm(am_core_warrior_radial_plane__scale)


[es(tag=gameClient, track=am_core_warrior__state, REQUIRE_NOT=am_core_warrior_attack_visual_controller__updatable)]
def am_core_warrior_attack_visual_controller_track_state(evt : Event;
                                                         eid : EntityId;
                                                         am_core_warrior__state : int)
  if am_core_warrior__state == int(CoreWarriorState.CHARGE)
    addSubTemplate(eid, "am_core_warrior_attack_visual_controller_updatable")


[es(tag=gameClient, REQUIRE=am_core_warrior_attack_visual_controller__updatable, before=am_core_warrior_radial_plane_update)]
def am_core_warrior_attack_visual_controller_update(act : UpdateStageInfoAct;
                                                    eid : EntityId;
                                                    am_core_warrior__chargeTime : float;
                                                    am_core_warrior__actAt : float;
                                                    am_core_warrior__state : int;
                                                    am_core_warrior__damageRadius : float;
                                                    am_core_warrior_attack_visual_controller__diskEid : EntityId;
                                                    am_core_warrior_attack_visual_controller__ringEid : EntityId)
  if am_core_warrior__state == int(CoreWarriorState.CHARGE)
    query(am_core_warrior_attack_visual_controller__diskEid) <| $ [es] (am_core_warrior_warning_disk__scale : float;
                                                                        var am_core_warrior_radial_plane__scale : float&)
      let duration = am_core_warrior__chargeTime
      let timePassed = act.curTime - am_core_warrior__actAt + duration
      let progress = saturate(timePassed / duration)
      let t = sqrt(progress)
      let maxScale = am_core_warrior__damageRadius * am_core_warrior_warning_disk__scale
      am_core_warrior_radial_plane__scale = lerp(0.0, maxScale, t)
    query(am_core_warrior_attack_visual_controller__ringEid) <| $ [es] (am_core_warrior_attack_ring__scale : float;
                                                                        am_core_warrior_attack_ring__activationTime : float;
                                                                        am_core_warrior_attack_ring__activationPow : float = 0.75;
                                                                        var am_core_warrior_radial_plane__scale : float&)
      let duration = am_core_warrior_attack_ring__activationTime
      let timePassed = act.curTime - am_core_warrior__actAt + duration
      let progress = saturate(timePassed / duration)
      let t = pow(progress, am_core_warrior_attack_ring__activationPow)
      let maxScale = am_core_warrior__damageRadius * am_core_warrior_attack_ring__scale
      am_core_warrior_radial_plane__scale = lerp(0.0, maxScale, t)
  else
    var planesDeactivated = true
    query(am_core_warrior_attack_visual_controller__diskEid) <| $ [es] (am_core_warrior_attack_ring__deactivationFactor : float = 7.0;
                                                                        var am_core_warrior_radial_plane__scale : float&)
      am_core_warrior_radial_plane__scale = lerp(am_core_warrior_radial_plane__scale, 0.0, am_core_warrior_attack_ring__deactivationFactor * act.dt)
      planesDeactivated &&= (am_core_warrior_radial_plane__scale <= 1e-3)
    query(am_core_warrior_attack_visual_controller__ringEid) <| $ [es] (am_core_warrior_attack_ring__deactivationFactor : float = 7.0;
                                                                        var am_core_warrior_radial_plane__scale : float&)
      am_core_warrior_radial_plane__scale = lerp(am_core_warrior_radial_plane__scale, 0.0, am_core_warrior_attack_ring__deactivationFactor * act.dt)
      planesDeactivated &&= (am_core_warrior_radial_plane__scale <= 1e-3)

    if planesDeactivated
      removeSubTemplate(eid, "am_core_warrior_attack_visual_controller_updatable")


[es(tag=gameClient, track=am_core_warrior__state, on_appear)]
def am_core_warrior_track_state_client(evt : Event;
                                       am_core_warrior__state : int;
                                       am_core_warrior__parentEid : EntityId;
                                       am_core_warrior_attack_visual_controller__diskEid : EntityId;
                                       am_core_warrior_attack_visual_controller__ringEid : EntityId;
                                       var animchar_render__enabled : bool&;
                                       var transform aka warrior_transform : float3x4)
  let warriorHidden = (am_core_warrior__state == int(CoreWarriorState.HIDDEN))

  if !animchar_render__enabled && !warriorHidden
    query(am_core_warrior__parentEid) <| $ [es] (transform aka core_transform : float3x4)
      warrior_transform[3] = core_transform[3]
  animchar_render__enabled = !warriorHidden

  if warriorHidden
    query(am_core_warrior_attack_visual_controller__diskEid) <| $ [es] (var am_core_warrior_radial_plane__scale : float&)
      am_core_warrior_radial_plane__scale = 0.0
    query(am_core_warrior_attack_visual_controller__ringEid) <| $ [es] (var am_core_warrior_radial_plane__scale : float&)
      am_core_warrior_radial_plane__scale = 0.0