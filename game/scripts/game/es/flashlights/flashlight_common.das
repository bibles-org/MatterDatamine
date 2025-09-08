module flashlight_common shared
require ecs


enum FlashlightType
  DEFAULT
  INFRARED


def find_flashlight(attaches_list : EidList;
                    human_weap__currentGunEid : EntityId;
                    find_cb : block<(flashlight_eid : EntityId; var is_on : bool&) : bool>)
  var found = false
  query(human_weap__currentGunEid) <| $ [es] (var gun_flashlight__isOn : bool&)
    if find_cb |> invoke(human_weap__currentGunEid, gun_flashlight__isOn)
      found = true

  if !found
    for attachEid in attaches_list
      query(attachEid) <| $ [es] (attached_flashlight_controller__entityEid : EntityId;
                                  flashlight_device__type : int)
        if flashlight_device__type != int(FlashlightType.DEFAULT)
          return

        query(attached_flashlight_controller__entityEid) <| $ [es] (var attached_flashlight__isOn : bool&)
          if find_cb |> invoke(attached_flashlight_controller__entityEid, attached_flashlight__isOn)
            found = true
  return found