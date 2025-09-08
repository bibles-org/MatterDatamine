require ecs
require ecs.common
require app
require math.base
require inventory
require DngNet
require DagorRandom
require DagorMath
require Grid
require GridCollision
require AnimV20
require Dacoll
require DngHumanAnim
require game.events.events_active_matter
require game.es.system_common


[es(tag=gameClient, on_appear, REQUIRE=sleeping_monster__animState, before=init_sleeping_trap_anim, after=init_navmesh_phys)]
def init_sleeping_trap_look_dir(evt : Event; var navmesh_phys__currentLookDir : float3&; transform : float3x4)
  navmesh_phys__currentLookDir = transform[0]


[es(on_appear, after=init_navmesh_phys)]
def init_sleeping_trap_anim(evt : Event;
                            animchar : AnimcharBaseComponent;
                            anim_state__animChannels : StringList;
                            sleeping_monster__animStateName : string;
                            navmesh_phys__currentLookDir : float3;
                            var sleeping_monster__appearTime : float&;
                            var transform : float3x4;
                            var animchar__animState : Object;
                            var sleeping_monster__animState : int&;
                            var animchar__animStateDirty : bool&)
  sleeping_monster__appearTime = get_sync_time()

  let animGraph = animchar.animGraph
  if animGraph != null
    sleeping_monster__animState = *animGraph |> anim_graph_getStateIdx(sleeping_monster__animStateName)

    for ch in anim_state__animChannels
      animchar__animState |> set(string(ch), sleeping_monster__animState)
    animchar__animStateDirty = true

  var t = 10.0
  var norm : float3
  let down = normalize(-transform[1])
  let from = transform[3] - 0.1 * down
  if traceray_normalized(from, down, t, norm)
    let end = from + down * t
    let up = -down
    let q = quat_rotation_arc(up, norm)
    let rotatedLook = q * navmesh_phys__currentLookDir
    transform[0] = normalize(rotatedLook)
    transform[1] = norm
    transform[2] = normalize(cross(rotatedLook, norm))
    transform[3] = end

/*
after=anim_state_es is a hack
In reality this system must work before others that change animchar__animState/
So that animchar__animState would be overwritten if necessary.
But ohers work in UpdateStageInfoAct.
So setting it after anim_state_es has the effect of making it first on the next frame
*/
[es(after=anim_state_es, parallel_for=4, REQUIRE_NOT=deadEntity)]
def set_sleeping_trap_anim(act : ParallelUpdateFrameDelayed;
                           anim_state__animChannels : StringList;
                           sleeping_monster__animState : int;
                           animchar__updatable : bool = true;
                           var animchar__animState : Object;
                           var animchar__animStateDirty : bool&)
  if !animchar__updatable
    return
  for ch in anim_state__animChannels
    animchar__animState |> set(string(ch), sleeping_monster__animState)
  animchar__animStateDirty = true


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def trigger_sleeping_trap(act : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          sleep_disturber__radius : float;
                          sleep_disturber__interval : float;
                          transform aka disturber_transform : float3x4;
                          var sleep_disturber__updateAt : float&)
  if sleep_disturber__updateAt < act.curTime
    sleep_disturber__updateAt = act.curTime + sleep_disturber__interval
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], sleep_disturber__radius), GridEntCheck.POS) <| $(trap_eid : EntityId)
      try_trigger_trap(trap_eid, eid, disturber_transform, sleep_disturber__radius)
    for_each_entity_in_grid(ecs_hash("creatures"), BSphere3(transform[3], sleep_disturber__radius), GridEntCheck.POS) <| $(trap_eid : EntityId)
      try_trigger_trap(trap_eid, eid, disturber_transform, sleep_disturber__radius)


def try_trigger_trap(eid, disturber : EntityId; disturber_transform : float3x4; sleep_disturber__radius : float)
  query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=sleeping_trap)] (transform aka trap_transform : float3x4;
                                                                       sleeping_trap__disturbProbabilityMult = 1.0;
                                                                       sleeping_monster__propagateCount = 0;
                                                                       sleeping_trap__radiusLimit = 100000.0)
    let dst = distance(trap_transform[3], disturber_transform[3])
    if dst < sleeping_trap__radiusLimit
      let probability = 1.0 - dst / min(sleeping_trap__radiusLimit, sleep_disturber__radius)
      if probability * sleeping_trap__disturbProbabilityMult > gfrnd()
        sendEventImmediate(eid, CmdAwakeSleepingMonster(propadateCount = sleeping_monster__propagateCount, disturber = disturber))


[es(tag=server, REQUIRE_NOT=sleeping_monster_awake_forbidden)]
def awake_sleeping_trap(evt : CmdAwakeSleepingMonster;
                        eid : EntityId;
                        transform : float3x4;
                        sleeping_trap__awakeRadius : float = 0.0;
                        loud_noise_reaction__addedTemplate : string = "";
                        sleeping_monster__template, sleeping_monster__templateAdd : string)
  let removeTempl = (empty(loud_noise_reaction__addedTemplate) ? sleeping_monster__template
                      : "{sleeping_monster__template}+{loud_noise_reaction__addedTemplate}")

  remote_change_sub_template(eid, removeTempl, sleeping_monster__templateAdd) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", eid)
  if sleeping_trap__awakeRadius > .0 && evt.propadateCount > 0
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], sleeping_trap__awakeRadius), GridEntCheck.POS) <| $(another_eid : EntityId)
      query(another_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=sleeping_monster)] ()
        sendEventImmediate(another_eid, CmdAwakeSleepingMonster(propadateCount = evt.propadateCount - 1, disturber = evt.disturber))


[es(tag=server, on_appear, REQUIRE=sleeping_monster)]
def disable_beh_tree_on_sleeping_monster_appear(evt : Event; var beh_tree__enabled : bool&)
  beh_tree__enabled = false


[es(tag=gameClient, REQUIRE=sleeping_animchar_update_toggle, before=animchar_es, REQUIRE_NOT=deadEntity, parallel_for=64)]
def sleep_animchar_update_toggle(act : ParallelUpdateFrameDelayed;
                                 animchar_visbits : animchar_visbits_t;
                                 sleeping_animchar__disableByDistance = false;
                                 sleeping_monster__appearTime : float;
                                 sleeping_animchar_update_toggle__forceUpdateAfterAppearTime : float = 10.0;
                                 var animchar__updatable : bool&)
  let isForceUpdate = (get_sync_time() - sleeping_monster__appearTime) < sleeping_animchar_update_toggle__forceUpdateAfterAppearTime

  let shadow_visible = int(animchar_visbits) & int(AnimcharVisbits.VISFLG_MAIN_VISIBLE)
  let camera_rendered = int(animchar_visbits) & int(AnimcharVisbits.VISFLG_MAIN_CAMERA_RENDERED)
  animchar__updatable = isForceUpdate || (!sleeping_animchar__disableByDistance && shadow_visible != 0 && camera_rendered != 0)


[es(tag=gameClient, no_order, REQUIRE=watchedByPlr)]
def sleep_animchar_update_toggle_by_distance(act : UpdateStageInfoAct;
                                             transform aka origin_transform : float3x4;
                                             sleeping_animchar_update_toggle_origin__radius : float;
                                             sleeping_animchar_update_toggle_origin__interval : float;
                                             var sleeping_animchar_update_toggle_origin__updateAt : float&)
  if sleeping_animchar_update_toggle_origin__updateAt < act.curTime
    sleeping_animchar_update_toggle_origin__updateAt = act.curTime + sleeping_animchar_update_toggle_origin__interval
    let raidusSq = square(sleeping_animchar_update_toggle_origin__radius)
    query() <| $ [es(REQUIRE=sleeping_animchar_update_toggle)] (transform aka animchar_transform : float3x4;
                                                                var sleeping_animchar__disableByDistance : bool&)
      sleeping_animchar__disableByDistance = distance_sq(animchar_transform[3], origin_transform[3]) > raidusSq


[es(tag=gameClient, after=sleep_animchar_update_toggle, before=animchar_es)]
def sleep_animchar_infrequent_update(act : ParallelUpdateFrameDelayed;
                                     animchar_infrequent_updater__interval : float;
                                     var animchar_infrequent_updater__updateAt : float&)
  if act.curTime > animchar_infrequent_updater__updateAt
    animchar_infrequent_updater__updateAt = act.curTime + animchar_infrequent_updater__interval
    query() <| $ [es(REQUIRE=sleeping_animchar_update_toggle, REQUIRE_NOT=deadEntity)] (var animchar__updatable : bool&)
      animchar__updatable = true

[es(tag=gameClient, on_disappear, REQUIRE=sleeping_animchar_update_toggle, REQUIRE_NOT=deadEntity)]
def enable_animchar_on_toggle_disappear(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = true


[es(tag=gameClient, parallel_for=4, after=sleep_animchar_update_toggle, REQUIRE=sleeping_animchar_update_toggle)]
def sleeping_animchar_update_toggle_update(evt : ParallelUpdateFrameDelayed;
                                           eid : EntityId;
                                           transform : float3x4;
                                           animchar__updatable : bool;
                                           animchar__visible : bool;
                                           var animchar : AnimcharBaseComponent;
                                           var animchar_attaches_bbox : bbox3f?;
                                           var animchar_render__root_pos : vec4f&;
                                           var animchar_bsph : vec4f&)
  if !animchar__updatable && !animchar__visible
    if is_entity_frame(eid, 120)
      // Rough animchar position update every 120 frames.
      // Required for setting animchar__visible value to the true
      // when approaching to the animchar at the rendering distance.
      // And true animchar__visible will set true animchar__updatable
      // at sleep_animchar_update_toggle es.
      animchar_set_tm(animchar, transform, true)
      animchar_render__root_pos = float4(transform[3], 1.0)
      let approxRadius = 2.5
      animchar_bsph = float4(transform[3], approxRadius)
      if animchar_attaches_bbox != null
        let bbox = BBox3(transform[3], approxRadius)
        animchar_attaches_bbox.bmin = float4(bbox.boxMin, 1.0)
        animchar_attaches_bbox.bmax = float4(bbox.boxMax, 1.0)
