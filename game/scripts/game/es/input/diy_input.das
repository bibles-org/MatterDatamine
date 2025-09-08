require ecs
require app
require net
require strings
require game.events.input_events
require game.events.events_active_matter
require DagorInput
require DagorSystem
require active_matter.game.es.abilities.diy_ability_common
require active_matter.game.es.ability_common


def init(var create, cancel, ret, rorate_up, rotate_down : int&)
  create = int(get_action_handle("Deploy.Create", TYPEGRP_DIGITAL))
  cancel = int(get_action_handle("Deploy.Cancel", TYPEGRP_DIGITAL))
  ret = int(get_action_handle("Deploy.Return", TYPEGRP_DIGITAL))
  rorate_up = int(get_action_handle("Deploy.RotateUp", TYPEGRP_DIGITAL))
  rotate_down = int(get_action_handle("Deploy.RotateDown", TYPEGRP_DIGITAL))


def reset(var create, cancel, ret, rorate_up, rotate_down : int&)
  create = int(BAD_ACTION_HANDLE)
  cancel = int(BAD_ACTION_HANDLE)
  ret = int(BAD_ACTION_HANDLE)
  rorate_up = int(BAD_ACTION_HANDLE)
  rotate_down = int(BAD_ACTION_HANDLE)

def init_device(var diy__input__useDevice : int&)
  diy__input__useDevice = int(get_action_handle("Human.Use", TYPEGRP_DIGITAL))

def reset_device(var diy__input__useDevice : int&)
  diy__input__useDevice = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear, REQUIRE=diy__previewEids, REQUIRE_NOT=diyPreviewControllerServer)]
def diy_input_preview_appear(evt : Event; preview__ownerEid : EntityId)
  query(preview__ownerEid) <| $ [es(REQUIRE=hero)] (var diy__input__create, diy__input__cancel, diy__input__return,
                                                    diy__input__rotateUp, diy__input__rotateDown : int&)
    init(diy__input__create, diy__input__cancel, diy__input__return, diy__input__rotateUp, diy__input__rotateDown)


[es(tag=input, on_disappear, REQUIRE=diy__previewEids, REQUIRE_NOT=diyPreviewControllerServer)]
def diy_input_preview_disappear(evt : Event; preview__ownerEid : EntityId)
  query(preview__ownerEid) <| $ [es(REQUIRE=hero)] (var diy__input__create, diy__input__cancel, diy__input__return,
                                                    diy__input__rotateUp, diy__input__rotateDown : int&)
    reset(diy__input__create, diy__input__cancel, diy__input__return, diy__input__rotateUp, diy__input__rotateDown)


[es(tag=input, on_appear, REQUIRE=hero)]
def diy_input_use_device_appear(evt : Event; var diy__input__useDevice : int&)
  init_device(diy__input__useDevice)

[es(tag=input)]
def diy_input__setup(evt : EventDaInputInit;
                     diy__previewEid : EntityId const?;
                     var diy__input__create, diy__input__cancel, diy__input__return,
                     diy__input__rotateUp, diy__input__rotateDown, diy__input__useDevice : int&)
  var hasPreview = (diy__previewEid != null)
  query() <| $ [es(REQUIRE=diy__previewEids)] (preview__ownerEid : EntityId)
    query(preview__ownerEid) <| $ [es(REQUIRE=hero)] ()
      hasPreview = true
  if evt.init
    init_device(diy__input__useDevice)
  else
    reset_device(diy__input__useDevice)

  if evt.init && hasPreview
    init(diy__input__create, diy__input__cancel, diy__input__return, diy__input__rotateUp, diy__input__rotateDown)
  else
    reset(diy__input__create, diy__input__cancel, diy__input__return, diy__input__rotateUp, diy__input__rotateDown)


[es(tag=input, REQUIRE=diy__previewTempl, on_appear)]
def diy_input_appear(evt : Event;
                     var diy__input__create, diy__input__cancel, diy__input__return,
                     diy__input__rotateUp, diy__input__rotateDown : int&)
  init(diy__input__create, diy__input__cancel, diy__input__return, diy__input__rotateUp, diy__input__rotateDown)


[es(tag=input, before=(human_common_input_action_triggered_es, human_input_weapon_action_triggered_es))]
def diy_input_es(evt : EventDaInputActionTriggered;
                 eid : EntityId;
                 hero_ability__abilities : Array;
                 input__enabled : bool;
                 diy__input__create : int;
                 diy__input__cancel : int;
                 diy__input__return : int;
                 diy__input__rotateUp : int;
                 diy__input__rotateDown : int;
                 diy__rotationEnabled : bool = true)
  if !input__enabled
    return
  if int(evt.action) == diy__input__create
    query(get_human_preview_eid(eid)) <| $ [es] (transform : float3x4)
      send_net_event(eid, RqDiyCreate(previewTransform = transform))
  elif int(evt.action) == diy__input__cancel
    query(get_human_preview_eid(eid)) <| $ [es] (eid : EntityId)
      destroyEntity(eid)
    let idx = get_ability_index_by_name(hero_ability__abilities, DIY_ABILITY_NAME)
    send_net_event(eid, RqCancelAbility(idx = idx))
  elif diy__rotationEnabled
    if int(evt.action) == diy__input__return
      query(get_human_preview_eid(eid)) <| $ [es] (preview__baseYawRotation : float; var additionalYawRotation : float&)
        additionalYawRotation = preview__baseYawRotation
    elif int(evt.action) == diy__input__rotateUp
      query(get_human_preview_eid(eid)) <| $ [es] (yawRotationSpeed : float; var additionalYawRotation : float&)
        additionalYawRotation += yawRotationSpeed
    elif int(evt.action) == diy__input__rotateDown
      query(get_human_preview_eid(eid)) <| $ [es] (yawRotationSpeed : float; var additionalYawRotation : float&)
        additionalYawRotation -= yawRotationSpeed


[es(tag=input)]
def diy_preview_template_input_track(evt : DiyAbilityAppearEffect;
                                     eid : EntityId;
                                     hero_ability__abilities : Array;
                                     diy__cancelAfterUse : bool)
  if diy__cancelAfterUse
    query(get_human_preview_eid(eid)) <| $ [es] (eid aka preview_eid : EntityId)
      destroyEntity(preview_eid)
    let idx = get_ability_index_by_name(hero_ability__abilities, DIY_ABILITY_NAME)
    send_net_event(eid, RqCancelAbility(idx = idx))