module gun_jamming_common shared
require ecs
require app
require net
require DagorMath
require game.es.human.human_gun_common


def abort_fix_jamming(gun_eid : EntityId)
  query(gun_eid) <| $ [es] (var gun_jamming__fixJammingEndAt : float&;
                            var gun_jamming__fixJammingStartAt : float&;
                            var gun_jamming__isJammed : bool&;
                            var gun_jamming__isJammedClient : bool?)
    if gun_jamming__fixJammingEndAt < 0.0
      return
    let progress = cvt(get_sync_time(), gun_jamming__fixJammingStartAt, gun_jamming__fixJammingEndAt, 0.0, 1.0)
    if progress >= 0.75 // ammo probably already fixed "visually"
      if gun_jamming__isJammedClient != null
        *gun_jamming__isJammedClient = false
      if is_server()
        gun_jamming__isJammed = false
    gun_jamming__fixJammingStartAt = -1.0
    gun_jamming__fixJammingEndAt = -1.0
    set_weapon_operation_state(int(GunOperationState.BOLTACTION), gun_eid)


def is_jamming_fix_in_progress(gun_eid : EntityId)
  var result = false
  query(gun_eid) <| $ [es] (gun_jamming__fixJammingEndAt : float)
    result = gun_jamming__fixJammingEndAt >= 0.0 && gun_jamming__fixJammingEndAt > get_sync_time()
  return result
