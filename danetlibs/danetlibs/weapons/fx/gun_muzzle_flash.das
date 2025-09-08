require ecs


[es(tag=gameClient, no_order)]
def gun_muzzle_flash_light_update(act : UpdateStageInfoAct;
                                  muzzle_flash_light__brightness : float;
                                  muzzle_flash_light__duration : float;
                                  muzzle_flash_light__fadeAt : float;
                                  var light__brightness : float&)
  if muzzle_flash_light__fadeAt > act.curTime
    light__brightness = lerp(.0, muzzle_flash_light__brightness, (muzzle_flash_light__fadeAt - act.curTime) / muzzle_flash_light__duration)
  else
    light__brightness = .0


[es(tag=gameClient, on_appear)]
def init_gun_muzzle_flash_light(evt : Event;
                                transform : float3x4;
                                human_weapon__muzzleFlashLightTemplate : string;
                                var human_weapon__muzzleFlashLightEid : EntityId&)
  human_weapon__muzzleFlashLightEid = createEntity(human_weapon__muzzleFlashLightTemplate) <| $(init)
    init |> set("transform", transform)


[es(tag=gameClient, on_disappear)]
def destroy_gun_muzzle_flash_light(evt : Event;
                                   human_weapon__muzzleFlashLightEid : EntityId)
  destroyEntity(human_weapon__muzzleFlashLightEid)