require ecs
require app
require ecs.safe
require math.base
require game.events.events_active_matter
require DagorMath
require math.color
require math.easing
require gameObject
require game.es.client.replicator_containers_common


def get_tranform_offset(offset : float3; transform : float3x4)
  var ret := transform
  ret[3] = ret[3] + offset
  return ret


def create_replicator_structure(templateName : string;
                                offset : float3;
                                transform : float3x4)
  return createEntity(templateName) <| $(var init)
    init |> set("transform", get_tranform_offset(offset, transform))


def destroy_replicator(var replicator_device__tableEid : EntityId&;
                       var replicator_device__moduleEid : EntityId&;
                       var replicator_device__tubeEid : EntityId&)
  destroyEntity(replicator_device__tableEid)
  replicator_device__tableEid = INVALID_ENTITY_ID

  destroyEntity(replicator_device__moduleEid)
  replicator_device__moduleEid = INVALID_ENTITY_ID

  destroyEntity(replicator_device__tubeEid)
  replicator_device__tubeEid = INVALID_ENTITY_ID


def create_replicator_if_needed(transform : float3x4;
                                replicator_device__tableTemplate : string;
                                replicator_device__tableOffset : float3;
                                var replicator_device__tableEid : EntityId&;
                                replicator_device__moduleTemplate : string;
                                replicator_device__moduleOffset : float3;
                                var replicator_device__moduleEid : EntityId&;
                                replicator_device__tubeTemplate : string;
                                replicator_device__tubeOffset : float3;
                                var replicator_device__tubeEid : EntityId&)
  if replicator_device__tableEid == INVALID_ENTITY_ID
    replicator_device__tableEid = create_replicator_structure(replicator_device__tableTemplate, replicator_device__tableOffset, transform)
  if replicator_device__moduleEid == INVALID_ENTITY_ID
    replicator_device__moduleEid = create_replicator_structure(replicator_device__moduleTemplate, replicator_device__moduleOffset, transform)
  if replicator_device__tubeEid == INVALID_ENTITY_ID
    replicator_device__tubeEid = create_replicator_structure(replicator_device__tubeTemplate, replicator_device__tubeOffset, transform)


def update_replicators(replicators_count : int)
  query()  <| $ [es] (replicator_device__slotIdx : int;
                      replicator_device__placed : bool;
                      transform : float3x4;
                      replicator_device__tableTemplate : string;
                      replicator_device__tableOffset : float3;
                      var replicator_device__tableEid : EntityId&;
                      replicator_device__moduleTemplate : string;
                      replicator_device__moduleOffset : float3;
                      var replicator_device__moduleEid : EntityId&;
                      replicator_device__tubeTemplate : string;
                      replicator_device__tubeOffset : float3;
                      var replicator_device__tubeEid : EntityId&)
    if (replicator_device__slotIdx >= replicators_count)
      destroy_replicator(replicator_device__tableEid, replicator_device__moduleEid, replicator_device__tubeEid)
    elif replicator_device__placed
      create_replicator_if_needed(transform,
                    replicator_device__tableTemplate,
                    replicator_device__tableOffset,
                    replicator_device__tableEid,
                    replicator_device__moduleTemplate,
                    replicator_device__moduleOffset,
                    replicator_device__moduleEid,
                    replicator_device__tubeTemplate,
                    replicator_device__tubeOffset,
                    replicator_device__tubeEid)


[es(tag=gameClient, track=player_profile__replicatorDevicesCount, on_event=EventLevelLoaded)]
def update_replicators_on_profile_change(evt : Event; player_profile__replicatorDevicesCount : int)
  update_replicators(player_profile__replicatorDevicesCount)


[es(tag=gameClient, track=replicator_tube__status, on_appear, after=animchar_with_dynamic_emission_appear, before=animchar_with_dynamic_emission_track_brightness)]
def replicator_tube_on_appear(evt : Event;
                              eid : EntityId;
                              var replicator_tube__status : int&)
  find_query() <| $ [es] (replicator_device__tubeEid : EntityId;
                          replicator_device__replicationEndAt : float;
                          replicator_device__resetingEndAt : float;
                          replicator_device__isEmpty : bool)
    if replicator_device__tubeEid != eid
      return false

    replicator_tube__status = get_replicator_status(replicator_device__replicationEndAt, replicator_device__resetingEndAt, replicator_device__isEmpty)
    return true


[es(tag=gameClient, track=replicator_tube__status, on_appear, after=animchar_with_dynamic_emission_appear, before=animchar_with_dynamic_emission_track_brightness)]
def track_replicator_tube_status(evt : Event;
                                 replicator_tube__status : int;
                                 replicator_tube__colorInProgress : E3DCOLOR;
                                 replicator_tube__colorDone : E3DCOLOR&;
                                 replicator_tube__colorEmpty : E3DCOLOR&;
                                 var animchar_with_dynamic_emission__color : E3DCOLOR&)
  if replicator_tube__status == int(TubeWorkStatus.REPLICATOR_EMPTY) || replicator_tube__status == int(TubeWorkStatus.REPLICATOR_RESETING)
    animchar_with_dynamic_emission__color = replicator_tube__colorEmpty
  elif (replicator_tube__status == int(TubeWorkStatus.REPLICATOR_IN_PROGRESS))
    animchar_with_dynamic_emission__color = replicator_tube__colorInProgress
  else
    animchar_with_dynamic_emission__color = replicator_tube__colorDone


def get_replicator_status(replicator_device__replicationEndAt : float;
                          replicator_device__resetingEndAt : float;
                          replicator_device__isEmpty : bool)
  let time = get_sync_time()
  if replicator_device__isEmpty
    return int(TubeWorkStatus.REPLICATOR_EMPTY)
  elif time > replicator_device__replicationEndAt
    return int(TubeWorkStatus.REPLICATOR_DONE)
  elif time < replicator_device__resetingEndAt
    return int(TubeWorkStatus.REPLICATOR_RESETING)
  else
    return int(TubeWorkStatus.REPLICATOR_IN_PROGRESS)


def set_replicator_status(replicator_device__tubeEid : EntityId;
                          replicator_device__replicationEndAt : float;
                          replicator_device__resetingEndAt : float;
                          replicator_device__isEmpty : bool)
  query(replicator_device__tubeEid) <| $ [es] (var replicator_tube__status : int&)
    replicator_tube__status = get_replicator_status(replicator_device__replicationEndAt, replicator_device__resetingEndAt, replicator_device__isEmpty)


[es(tag=gameClient, no_order)]
def tube_work_update(act : UpdateStageInfoAct;
                     replicator_tube__status : int;
                     replicator_tube__colorInProgressMax : E3DCOLOR;
                     replicator_tube__colorInProgress : E3DCOLOR;
                     replicator_tube__colorDoneMax : E3DCOLOR;
                     replicator_tube__colorDone : E3DCOLOR;
                     replicator_tube__colorPulsationPeriod : float;
                     var animchar_with_dynamic_emission__color : E3DCOLOR&)
  if (replicator_tube__status != int(TubeWorkStatus.REPLICATOR_IN_PROGRESS)
   && replicator_tube__status != int(TubeWorkStatus.REPLICATOR_DONE))
    return

  let k = cosineFull(act.curTime / replicator_tube__colorPulsationPeriod)
  if replicator_tube__status == int(TubeWorkStatus.REPLICATOR_IN_PROGRESS)
    animchar_with_dynamic_emission__color = e3dcolor_lerp(replicator_tube__colorInProgress, replicator_tube__colorInProgressMax, k)
  elif replicator_tube__status == int(TubeWorkStatus.REPLICATOR_DONE)
    animchar_with_dynamic_emission__color = e3dcolor_lerp(replicator_tube__colorDone, replicator_tube__colorDoneMax, k)


[es(tag=gameClient, no_order)]
def replicator_work_update(act : UpdateStageInfoAct;
                           transform aka replicator_transform : float3x4;
                           replicator_device__tableEid : EntityId;
                           replicator_device__tubeEid : EntityId;
                           replicator_device__replicationEndAt : float;
                           replicator_device__replicationTime : float;
                           replicator_device__resetingEndAt : float;
                           replicator_device__resetingTime : float;
                           replicator_device__tableOffset : float3;
                           replicator_device__isEmpty : bool;
                           var replicator_device__replicationReady : bool&)

  if (act.curTime > replicator_device__replicationEndAt && !replicator_device__replicationReady)
    replicator_device__replicationReady = true
    set_replicator_status(replicator_device__tubeEid, replicator_device__replicationEndAt, replicator_device__resetingEndAt, replicator_device__isEmpty)

  if (act.curTime > replicator_device__replicationEndAt)
    return

  var progress = 0.0
  if act.curTime < replicator_device__resetingEndAt
    let timeLeft = replicator_device__resetingEndAt - act.curTime
    progress = inOutQuad(timeLeft / replicator_device__resetingTime)
  else
    let timeLeft = replicator_device__replicationEndAt - act.curTime
    progress = 1.0 - (timeLeft / (replicator_device__replicationTime - replicator_device__resetingTime))
  progress = clamp(progress, 0.0001, 1.0)

  var tableFixedPositionY = 0.0
  query(replicator_device__tubeEid) <| $ [es] (var transform : float3x4; animchar_bbox : bbox3f)
    transform[1][1] = progress
    tableFixedPositionY = animchar_bbox.bmax.y - animchar_bbox.bmin.y

  query(replicator_device__tableEid) <| $ [es] (var transform : float3x4)
    let pos = replicator_transform[3] + replicator_device__tableOffset - float3(0.0, tableFixedPositionY, 0.0)
    transform[3] = pos

  set_replicator_status(replicator_device__tubeEid, replicator_device__replicationEndAt, replicator_device__resetingEndAt, replicator_device__isEmpty)


[es(tag=gameClient)]
def set_replicator_data(evt : EventSetReplicatorData;
                        replicator_device__slotIdx : int;
                        replicator_device__tubeEid : EntityId;
                        replicator_device__resetingTime : float;
                        var replicator_device__replicationEndAt : float&;
                        var replicator_device__resetingEndAt : float&;
                        var replicator_device__replicationTime : float&;
                        var replicator_device__replicationReady : bool&;
                        var replicator_device__isEmpty : bool&)
  if replicator_device__slotIdx != evt.replicatorIdx
    return

  replicator_device__isEmpty = evt.replicatorIsEmpty
  replicator_device__replicationEndAt = evt.replicatorDoneAt
  replicator_device__replicationReady = (get_sync_time() > replicator_device__replicationEndAt) && evt.replicatorTime != 0.0
  replicator_device__replicationTime = evt.replicatorTime
  replicator_device__resetingEndAt = replicator_device__replicationEndAt - replicator_device__replicationTime + replicator_device__resetingTime
  set_replicator_status(replicator_device__tubeEid, replicator_device__replicationEndAt, replicator_device__resetingEndAt, replicator_device__isEmpty)


[es(tag=gameClient, on_event=EventLevelLoaded, before=update_replicators_on_profile_change)]
def place_replicators_on_gameobject(evt : Event; player_profile__replicatorDevicesCount : int)
  query()  <| $ [es] (replicator_device__placeOnObject : string;
                      var replicator_device__placed : bool&;
                      var transform : float3x4&)
    if empty(replicator_device__placeOnObject)
      return
    find_query() <| $ [es] (game_objects : GameObjects)
      let scene = game_objects |> get_scene_game_objects_by_name(replicator_device__placeOnObject)
      if scene != null
        scene |> find_scene_game_objects() <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
          transform := tm
          replicator_device__placed = true
          return true
      return true

  update_replicators(player_profile__replicatorDevicesCount)