require ecs
require app
require math
require AnimV20
require CollRes
require math.ang
require ecs.safe
require DngCamera
require math.base
require DagorMath
require DagorInput
require DagorSystem
require DagorStdGuiRender
require game.events.events
require game.events.events_active_matter
require game.es.client.postfx_fade_common
require DngActor


enum ShowStates
  NOT_IN_SHOWROOM = 0
  FADEIN_TO_SHOWROOM
  FADEOUT_TO_SHOWROOM
  IN_SHOWROOM
  FADEIN_OUT_SHOWROOM
  FADEOUT_OUT_SHOWROOM


def private fade_showroom(var current_state : int&; time : float)
  var needToShow = current_state != int(ShowStates.FADEIN_TO_SHOWROOM)
  needToShow &&= current_state != int(ShowStates.FADEOUT_TO_SHOWROOM)
  needToShow &&= current_state != int(ShowStates.IN_SHOWROOM)
  if needToShow
    current_state = int(ShowStates.FADEIN_TO_SHOWROOM)
    postfx_fadein(time / 2.0, int(ecs_hash("showroom_fade")))


def private hide_showroom(var current_state : int&; time : float)
  var needToHide = current_state != int(ShowStates.NOT_IN_SHOWROOM)
  needToHide &&= current_state != int(ShowStates.FADEIN_OUT_SHOWROOM)
  needToHide &&= current_state != int(ShowStates.FADEOUT_OUT_SHOWROOM)
  if needToHide
    current_state = int(ShowStates.FADEIN_OUT_SHOWROOM)
    postfx_fadein(time / 2.0, int(ecs_hash("showroom_fade")))


[es(track=showroom_item_place__isCurrent)]
def showroom_place_init(evt : Event;
                        transform : float3x4;
                        showroom_item_place__isCurrent : bool;
                        showroom_item_place__lights : Object;
                        var showroom_item_place__lightEids : EidList;
                        var showroom_item_place__itemInPlaceEid : EntityId&)
  if showroom_item_place__isCurrent
    for lightEntity in showroom_item_place__lights
      let lightEid = createEntity(lightEntity.key) <| $(var init)
        init |> set("transform", transform * (get_TMatrix(lightEntity.value) ?? IDENT_TM))
      showroom_item_place__lightEids |> push(lightEid)
  else
    for lightEid in showroom_item_place__lightEids
      destroyEntity(lightEid)
    clear(showroom_item_place__lightEids)
    destroyEntity(showroom_item_place__itemInPlaceEid)
    showroom_item_place__itemInPlaceEid = INVALID_ENTITY_ID


[es(on_disappear)]
def showroom_lights_clear(evt : Event; showroom_item_place__lightEids : EidList)
  for lightEid in showroom_item_place__lightEids
    destroyEntity(lightEid)


[es]
def look_at_showroom(evt : EventActivateShowroom;
                     showroom_cam__fadeInOutTime : float2;
                     var fov : float&;
                     var showroom_cam__wishItemPlaceEid : EntityId&;
                     var showroom_cam__screenPos, showroom_cam__screenSize : float2&;
                     var showroom_cam__currentState : int&;
                     var showroom_cam__zoomBordersRng : float2&)
  find_query() <| $ [es] (eid : EntityId;
                          showroom_item_place__key : string;
                          showroom_item_place__fov : float;
                          showroom_item_place__zoomBordersRng : float2 const?)
    if (evt.showroomKey != showroom_item_place__key)
      return false

    fov = showroom_item_place__fov
    if showroom_item_place__zoomBordersRng != null
      showroom_cam__zoomBordersRng = *showroom_item_place__zoomBordersRng

    query(showroom_cam__wishItemPlaceEid) <| $ [es] (var showroom_item_place__isCurrent : bool&)
      showroom_item_place__isCurrent = false
    showroom_cam__wishItemPlaceEid = eid
    query(showroom_cam__wishItemPlaceEid) <| $ [es] (var showroom_item_place__isCurrent : bool&)
      showroom_item_place__isCurrent = true

    showroom_cam__screenPos = evt.placeScreenPosition
    showroom_cam__screenSize = evt.placeScreenSize

    fade_showroom(showroom_cam__currentState, showroom_cam__fadeInOutTime.x)
    return true


def setZoomBorderRng(itemTemplate)
  find_query()  <| $ [es] (showroom_cam__zoomDefaultBordersRng : float2; showroom_cam__defaultZoom : float; var showroom_cam__zoomBordersRng : float2&; var showroom_cam__zoom : float&)
    if (itemTemplate == null)
      showroom_cam__zoomBordersRng = showroom_cam__zoomDefaultBordersRng
      showroom_cam__zoom = showroom_cam__defaultZoom
      return true

    showroom_cam__zoom = *itemTemplate |> getTemplateComponent("showroom_item__customZoom") ?? showroom_cam__defaultZoom
    showroom_cam__zoomBordersRng = *itemTemplate |> getTemplateComponent("showroom_item__customZoomBordersRng") ?? showroom_cam__zoomDefaultBordersRng
    return true


[es(track=showroom_cam__itemPlaceEid)]
def showroom_action_set_disabler(evt : Event; showroom_cam__itemPlaceEid : EntityId)
  activate_action_set(get_action_set_handle("Human"), showroom_cam__itemPlaceEid == INVALID_ENTITY_ID)


[es(on_disappear, REQUIRE=showroom_cam__itemPlaceEid)]
def showroom_action_set_enable_on_destroy(evt : Event)
  activate_action_set(get_action_set_handle("Human"), true)


[es]
def place_item_in_showroom(evt : EventShowItemInShowroom)
  find_query() <| $ [es(REQUIRE=showroom_item_place)] (transform : float3x4&; showroom_item_place__key : string; var showroom_item_place__itemInPlaceEid : EntityId&)
    if (evt.showroomKey != showroom_item_place__key)
      return false

    var startAngle = 0.0
    query(showroom_item_place__itemInPlaceEid)  <| $ [es] (showroom_item__rotationAngle : float)
      startAngle = showroom_item__rotationAngle

    destroyEntity(showroom_item_place__itemInPlaceEid)

    var itemEid = INVALID_ENTITY_ID
    let weaponTemplate = evt.data?["__weapon"] ?? ""
    let alterTemplate = evt.data?["__alter"] ?? ""
    let forceAnimState = evt.data?["forceAnimState"] ?? "flask_float"

    if !empty(weaponTemplate)
      var animcharName = ""
      let itemTempl = getOrBuildTemplateByName(weaponTemplate)
      setZoomBorderRng(itemTempl)
      if itemTempl != null
        animcharName = *itemTempl |> getTemplateComponent("item__animcharInInventoryName") ?? animcharName
      itemEid = createEntity("{weaponTemplate}+showroom_item") <| $(var init)
        init |> set("showroom_item__base_transform", transform)
        init |> set("gun__ammo", 1)
        init |> set("showroom_item__rotationAngle", startAngle)
        if !empty(animcharName)
          init |> set("animchar__res", animcharName)
        using() <| $(var attaches : Object)
          for attachment in *evt.data
            if attachment.key != "__weapon"
              using() <| $(var attach : Object)
                attach |> set("templateName", attachment.value ?? "")
                attach |> set("ammoRange", int2(0, 0))
                attaches |> set(attachment.key, attach)
          init |> set("initial_weapon_mods__list", attaches)
    elif !empty(alterTemplate)
      var animcharName = ""
      let itemTempl = getOrBuildTemplateByName(alterTemplate)
      setZoomBorderRng(itemTempl)
      if itemTempl != null
        animcharName = *itemTempl |> getTemplateComponent("animchar__res") ?? animcharName
      itemEid = createEntity("showroom_item+floating_sleeve+am_militant_ribbons") <| $(var init)
        init |> set("anim_state__forceAnimState", forceAnimState)
        using() <| $(var anim_state : Object)
          anim_state |> set("upper", forceAnimState)
          anim_state |> set("lower", forceAnimState)
          init |> set("animchar__animStateNames", anim_state)
        init |> set("showroom_item__base_transform", transform)
        init |> set("showroom_item__rotationAngle", startAngle)
        init |> set("showroom_item__autoRotationEnabled", false)
        find_query() <| $ [es(REQUIRE=(watchedPlayerItem, suit_militant_attachable_animchar))] (shader_color__colors : Point4List)
          init |> set("shader_color__colors", shader_color__colors)
          return true
        if evt.data?["floatingAmplitude"] != null
          init |> set("static_sinusoidal_oscillation__amplitude", evt.data?["floatingAmplitude"] ?? 0.0)

        if !empty(animcharName)
          init |> set("animchar__res", animcharName)
    showroom_item_place__itemInPlaceEid = itemEid
    return true


def calc_camera_position(item_base_pos : float3;
                         fov : float;
                         item_size : float3;
                         item_screen_size : float2;
                         item_screen_pos : float2;
                         zoom = 1.0) : float3
  if item_screen_size.x <= VERY_SMALL_NUMBER || item_screen_size.y <= VERY_SMALL_NUMBER
    return item_base_pos
  var itemScreenSize = item_screen_size

  let screenSize = StdGuiRender_screen_size()
  var worldPoint : float3
  var worldDir : float3
  screen_to_world(item_screen_pos, worldPoint, worldDir)

  let sizeXZ = max(item_size.x, item_size.z)
  if sizeXZ <= VERY_SMALL_NUMBER || item_size.y <= VERY_SMALL_NUMBER
    return item_base_pos

  if item_size.y > sizeXZ
    itemScreenSize.x = itemScreenSize.y * sizeXZ / item_size.y
  else
    itemScreenSize.y = itemScreenSize.x * item_size.y / sizeXZ

  let w = screenSize.x * sizeXZ / itemScreenSize.x
  let shiftZZ = (1.0 / tan(fov * DEG_TO_RAD / 2.0)) * 0.5 * w
  let shiftZX = (item_screen_pos.x * w) / (screenSize.x * 2.0)
  let shiftZSq = square(shiftZZ) + square(shiftZX)

  let h = screenSize.y * item_size.y / itemScreenSize.y
  let fovVert2 = 2.0 * RAD_TO_DEG * asin((screenSize.y / screenSize.x) * sin(fov * DEG_TO_RAD / 2.0))
  let shiftXZ = (1.0 / tan(fovVert2 * DEG_TO_RAD / 2.0)) * 0.5 * h
  let shiftXX = (item_screen_pos.y * h) / (screenSize.y * 2.0)
  let shiftXSq = square(shiftXZ) + square(shiftXX)

  let shift = sqrt(shiftXSq - ((shiftZSq - shiftXSq) / ((square(item_screen_pos.y) / square(item_screen_pos.x)) - 1.0)))

  return item_base_pos - worldDir * shift * zoom


[es(on_event=EventDelayedFrameAction)]
def set_showroom_camera(evt : Event;
                        showroom_cam__itemPlaceEid : EntityId;
                        showroom_cam__screenPos, showroom_cam__screenSize : float2;
                        showroom_cam__zoom : float&;
                        fov : float;
                        var showroom_cam__targetPos : float3&;
                        var transform aka cam_transform : float3x4&)
  query(showroom_cam__itemPlaceEid) <| $[es] (showroom_item_place__itemInPlaceEid : EntityId;
                                              transform aka item_place_transform : float3x4)
    cam_transform = item_place_transform
    orthonormalize(cam_transform)
    var isItemFound = false
    query(showroom_item_place__itemInPlaceEid) <| $[es] (collres : CollisionResource; showroom_item__item_transform : float3x4)
      let itemSize = showroom_item__item_transform * collres.boundingBox
      cam_transform[3] = calc_camera_position(item_place_transform[3], fov, itemSize.width, showroom_cam__screenSize, showroom_cam__screenPos, showroom_cam__zoom)
      showroom_cam__targetPos = cam_transform[3]
      isItemFound = true

    if !isItemFound
      let itemSize = float3(
        length(item_place_transform[0]),
        length(item_place_transform[1]),
        length(item_place_transform[2])
      )
      cam_transform[3] = calc_camera_position(item_place_transform[3], fov, itemSize, showroom_cam__screenSize, showroom_cam__screenPos)
      showroom_cam__targetPos = cam_transform[3]


[es]
def showroom_camera_fade(evt : EventPostFxFadeFinished;
                         showroom_cam__fadeInOutTime : float2;
                         showroom_cam__zoomBordersRng : float2;
                         showroom_cam__screenPos, showroom_cam__screenSize : float2;
                         eid, showroom_cam__wishItemPlaceEid : EntityId;
                         fov : float;
                         var showroom_cam__itemPlaceEid : EntityId&;
                         var showroom_cam__zoom : float&;
                         var showroom_cam__currentState : int&;
                         var showroom_cam__targetPos : float3&;
                         var transform aka cam_transform : float3x4&;
                         var camera__active : bool&)
  let layerNameHash = int(ecs_hash("showroom_fade"))
  if evt.layerNameHash != layerNameHash
    return

  if showroom_cam__currentState == int(ShowStates.FADEIN_TO_SHOWROOM)
    find_query() <| $ [es(REQUIRE=camera__target)] (var camera__active : bool&)
      camera__active = false
      return true
    set_scene_camera_entity(eid)
    postfx_fadeout(showroom_cam__fadeInOutTime.x / 2.0, layerNameHash)
    showroom_cam__itemPlaceEid = showroom_cam__wishItemPlaceEid
    query(showroom_cam__itemPlaceEid) <| $ [es] (transform : float3x4)
      cam_transform[3] = transform[3]
      for i in range(3)
        cam_transform[i] = normalize(transform[i])
    showroom_cam__zoom = showroom_cam__zoomBordersRng.y

    showroom_cam__currentState = int(ShowStates.FADEOUT_TO_SHOWROOM)

    //to trigger set_showroom_camera in next frame so camera will be changed already
    //and fade still on the screen
    createEntitySync("action_on_delayed_frame") <| $(var init)
      set(init, "action_on_delayed_frame__recipient", eid)
      set(init, "action_on_delayed_frame__frame", int(get_dagor_frame_no()) + 1)

  elif showroom_cam__currentState == int(ShowStates.FADEOUT_TO_SHOWROOM)
    showroom_cam__currentState = int(ShowStates.IN_SHOWROOM)
    query(showroom_cam__wishItemPlaceEid) <| $ [es] (showroom_item_place__itemInPlaceEid : EntityId;
                                                     showroom_item__item_transform, transform aka full_item_transform : float3x4)
      query(showroom_item_place__itemInPlaceEid) <| $[es] (collres : CollisionResource)
        let itemSize = showroom_item__item_transform * collres.boundingBox
        cam_transform[3] = calc_camera_position(full_item_transform[3], fov, itemSize.width, showroom_cam__screenSize, showroom_cam__screenPos)
        showroom_cam__targetPos = cam_transform[3]

  elif showroom_cam__currentState == int(ShowStates.FADEIN_OUT_SHOWROOM)
    camera__active = false
    find_query() <| $ [es(REQUIRE=camera__target)] (eid aka other_cam_eid : EntityId)
      set_scene_camera_entity(other_cam_eid)
      return true
    postfx_fadeout(showroom_cam__fadeInOutTime.y / 2.0, layerNameHash)
    showroom_cam__currentState = int(ShowStates.FADEOUT_OUT_SHOWROOM)

  elif showroom_cam__currentState == int(ShowStates.FADEOUT_OUT_SHOWROOM)
    showroom_cam__currentState = int(ShowStates.NOT_IN_SHOWROOM)


def rotate_item(angle : float; item_tm : float3x4; var base_tm, result_tm : float3x4)
  let rotQ = quat(float3(0.0, 1.0, 0.0), angle)
  var rotateTm = IDENT_TM
  make_tm(rotQ, rotateTm)
  base_tm = base_tm * rotateTm
  result_tm = base_tm * item_tm


[es(on_appear, REQUIRE=showroom_item)]
def prepare_showroom_item(evt : Event;
                          eid : EntityId;
                          animchar : AnimcharBaseComponent;
                          weapon__iconPitch, weapon__iconRoll, weapon__iconYaw : float const?;
                          showroom_item__rotationAngle : float;
                          collres : CollisionResource;
                          var showroom_item__item_transform, showroom_item__base_transform, transform aka full_item_transform : float3x4&;
                          item__iconPitch : float = 0.0f; item__iconRoll : float = 0.0f; item__iconYaw : float = 0.0f;
                          item__showroomOffset = float3(0.0))
  // same as in animchar icon renderer
  var rotQ : quat
  let yaw = DEG_TO_RAD * (weapon__iconYaw ?? item__iconYaw)
  let roll = DEG_TO_RAD * (weapon__iconRoll ?? item__iconRoll)
  let pitch = DEG_TO_RAD * (weapon__iconPitch ?? item__iconPitch)
  euler_to_quat(-yaw, -pitch, roll, rotQ)
  make_tm(rotQ, showroom_item__item_transform)
  var animcharRootTm : float3x4
  animchar |> animchar_get_tm(animcharRootTm)
  showroom_item__item_transform = inverse(showroom_item__item_transform) * inverse(animcharRootTm)
  showroom_item__item_transform[3] = showroom_item__item_transform * (-collres.boundingBox.center + item__showroomOffset)
  full_item_transform = showroom_item__base_transform * showroom_item__item_transform

  rotate_item(showroom_item__rotationAngle, showroom_item__item_transform, showroom_item__base_transform, full_item_transform)

  find_query() <| $ [es] (camera__active : bool;
                          showroom_cam__zoom : float;
                          showroom_cam__screenSize, showroom_cam__screenPos : float2;
                          showroom_cam__itemPlaceEid : EntityId;
                          fov : float;
                          var showroom_cam__targetPos : float3&)
    query(showroom_cam__itemPlaceEid) <| $ [es] (showroom_item_place__itemInPlaceEid : EntityId)
      if camera__active && showroom_item_place__itemInPlaceEid == eid
        let itemSize = showroom_item__item_transform * collres.boundingBox
        showroom_cam__targetPos = calc_camera_position(showroom_item__base_transform[3],
                                                       fov,
                                                       itemSize.width,
                                                       showroom_cam__screenSize,
                                                       showroom_cam__screenPos,
                                                       showroom_cam__zoom)
    return true


[es(no_order)]
def showroom_smooth_camera_movement(act : ParallelUpdateFrameDelayed;
                                    showroom_cam__currentState : int&;
                                    showroom_cam__targetPos : float3;
                                    var transform : float3x4&)
  if showroom_cam__currentState == int(ShowStates.FADEIN_TO_SHOWROOM)
    return

  if distance_sq(showroom_cam__targetPos, transform[3]) < 0.00001
    transform[3] = showroom_cam__targetPos
  else
    transform[3] = approach(transform[3], showroom_cam__targetPos, act.dt, 0.3)


[es]
def deactivate_showroom(evt : EventCloseShowroom)
  let isEditorActive = find_query() <| $ [es] (editor_active_marker__isActive : bool)
    return editor_active_marker__isActive
  if isEditorActive
    return
  find_query() <| $ [es] (showroom_cam__fadeInOutTime : float2;
                          var showroom_cam__currentState : int&;
                          var showroom_cam__wishItemPlaceEid : EntityId&;
                          var showroom_cam__itemPlaceEid : EntityId&)
    query(showroom_cam__itemPlaceEid) <| $ [es] (var showroom_item_place__isCurrent : bool&)
      showroom_item_place__isCurrent = false
    query(showroom_cam__wishItemPlaceEid) <| $ [es] (var showroom_item_place__isCurrent : bool&)
      showroom_item_place__isCurrent = false
    showroom_cam__itemPlaceEid = INVALID_ENTITY_ID
    showroom_cam__wishItemPlaceEid = INVALID_ENTITY_ID
    hide_showroom(showroom_cam__currentState, showroom_cam__fadeInOutTime.y)
    reset_rotation(showroom_cam__itemPlaceEid)
    return true

  activate_action_set(get_action_set_handle("Human"), true)


[es(no_order, REQUIRE=showroom_item)]
def showroom_autorotate_item(act : ParallelUpdateFrameDelayed;
                             showroom_item__item_transform : float3x4;
                             showroom_item__autoRotationEnabled : bool;
                             var showroom_item__rotationAngle : float&;
                             var showroom_item__base_transform, transform : float3x4&;
                             showroom_item__rotationSpd = 0.4)
  if !showroom_item__autoRotationEnabled
    return

  showroom_item__rotationAngle = norm_ang(showroom_item__rotationAngle + act.dt * showroom_item__rotationSpd)
  rotate_item(act.dt * showroom_item__rotationSpd, showroom_item__item_transform, showroom_item__base_transform, transform)


def reset_rotation(itemPlaceEid : EntityId)
  query(itemPlaceEid) <| $ [es] (showroom_item_place__itemInPlaceEid : EntityId; transform aka item_place_transform : float3x4&)
    query(showroom_item_place__itemInPlaceEid) <| $ [es] (var showroom_item__base_transform : float3x4&;
                                                          var showroom_item__item_transform : float3x4&;
                                                          var showroom_item__rotationAngle : float&;
                                                          var transform : float3x4&)
      transform = item_place_transform
      showroom_item__item_transform = item_place_transform
      showroom_item__base_transform = item_place_transform
      showroom_item__rotationAngle = 0.0


[es]
def showroom_process_rotation(evt : EventUIMouseMoved; showroom_cam__itemPlaceEid : EntityId)
  query(showroom_cam__itemPlaceEid) <| $ [es] (showroom_item_place__itemInPlaceEid : EntityId)
    query(showroom_item_place__itemInPlaceEid) <| $ [es] (showroom_item__item_transform : float3x4;
                                                          var showroom_item__rotationAngle : float&;
                                                          var showroom_item__autoRotationEnabled : bool&;
                                                          var showroom_item__base_transform, transform : float3x4&)
      showroom_item__autoRotationEnabled = false
      showroom_item__rotationAngle = norm_ang(showroom_item__rotationAngle - evt.screenX * 0.01)
      rotate_item(-evt.screenX * 0.01, showroom_item__item_transform, showroom_item__base_transform, transform)


[es]
def showroom_process_zoom(evt : EventUIMouseWheelUsed;
                          showroom_cam__itemPlaceEid : EntityId;
                          showroom_cam__zoomMult : float;
                          showroom_cam__zoomBordersRng : float2;
                          showroom_cam__screenSize, showroom_cam__screenPos : float2;
                          fov : float;
                          var showroom_cam__zoom : float&;
                          var showroom_cam__targetPos : float3&)
  query(showroom_cam__itemPlaceEid) <| $ [es] (showroom_item_place__itemInPlaceEid : EntityId; transform : float3x4)
    showroom_cam__zoom = clamp(showroom_cam__zoom - evt.value * showroom_cam__zoomMult,
      showroom_cam__zoomBordersRng.x, showroom_cam__zoomBordersRng.y)
    query(showroom_item_place__itemInPlaceEid) <| $ [es] (collres : CollisionResource;
                                                          showroom_item__item_transform : float3x4)
      let itemSize = showroom_item__item_transform * collres.boundingBox
      showroom_cam__targetPos = calc_camera_position(transform[3],
                                                     fov,
                                                     itemSize.width,
                                                     showroom_cam__screenSize,
                                                     showroom_cam__screenPos,
                                                     showroom_cam__zoom)
