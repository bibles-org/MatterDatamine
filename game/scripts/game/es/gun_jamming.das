require ecs
require app
require net
require DngHuman
require PhysVars
require DagorMath
require game.events.events
require game.events.events_game
require game.es.gun_jamming_common
require game.es.human.human_gun_common


[es(tag=gameClient, track=gun_jamming__isJammedClient)]
def process_jamming_animation(evt : Event;
                              gun_jamming__isJammedClient : bool;
                              gun_anim_v2__isJammingVarId : int;
                              var phys_vars : PhysVars)
  phys_vars |> setVar(gun_anim_v2__isJammingVarId, gun_jamming__isJammedClient ? 1.0 : 0.0)


[es(tag=gameClient, track=gun_jamming__isJammed)]
def track_server_jamming(evt : Event;
                         gun_jamming__isJammed : bool;
                         var gun_jamming__isJammedClient : bool&)
  gun_jamming__isJammedClient = gun_jamming__isJammed


[es(tag=gameClient, REQUIRE=hero)]
def start_fix_jamming_animation_hero(evt : CmdRequestFixJamming;
                                     human_weap__currentGunEid : EntityId)
  if human_weap__currentGunEid == evt.gunEid
    set_weapon_operation_state(int(GunOperationState.FIX_JAMMING), evt.gunEid)
    query(evt.gunEid) <| $ [es] (gun_jamming__fixJammingTime : float;
                                 var gun_jamming__fixJammingEndAt : float&;
                                 var gun_jamming__fixJammingStartAt : float&)
      gun_jamming__fixJammingStartAt = get_sync_time()
      gun_jamming__fixJammingEndAt = gun_jamming__fixJammingStartAt + gun_jamming__fixJammingTime


[es(tag=server, REQUIRE_NOT=hero)]
def start_fix_jamming_animation_server(evt : CmdRequestFixJamming;
                                       human_weap__currentGunEid : EntityId)
  if human_weap__currentGunEid == evt.gunEid
    set_weapon_operation_state(int(GunOperationState.FIX_JAMMING), evt.gunEid)
    query(evt.gunEid) <| $ [es] (gun_jamming__fixJammingTime : float;
                                 var gun_jamming__fixJammingEndAt : float&;
                                 var gun_jamming__fixJammingStartAt : float&)
      gun_jamming__fixJammingStartAt = get_sync_time()
      gun_jamming__fixJammingEndAt = gun_jamming__fixJammingStartAt + gun_jamming__fixJammingTime


[es(tag=gameClient, track=gun_jamming__fixJammingEndAt)]
def start_fix_jamming_animation_shadows(evt : Event;
                                        eid, gun__owner : EntityId;
                                        gun_jamming__fixJammingEndAt : float;
                                        var gun_jamming__fixJammingStartAt : float&)
  if gun__owner |> has("hero")
    return
  gun_jamming__fixJammingStartAt = min(get_sync_time(), gun_jamming__fixJammingEndAt)
  set_weapon_operation_state(int(GunOperationState.FIX_JAMMING), eid)


[es(tag=server, no_order)]
def fix_jamming_process_server(act : UpdateStageInfoAct;
                               var gun_jamming__fixJammingEndAt : float&;
                               var gun_jamming__fixJammingStartAt : float&;
                               var gun_jamming__isJammed : bool&)
  if gun_jamming__fixJammingEndAt < 0.0
    return
  let progress = cvt(act.curTime, gun_jamming__fixJammingStartAt, gun_jamming__fixJammingEndAt, 0.0, 1.0)
  if progress >= 1.0
    gun_jamming__isJammed = false
    gun_jamming__fixJammingStartAt = -1.0
    gun_jamming__fixJammingEndAt = -1.0


[es(tag=gameClient, no_order)]
def fix_jamming_process_client(act : UpdateStageInfoAct;
                               gun_anim_v2__currentOperationState : int;
                               gun_anim_v2__operationProgressVarId : int;
                               eid : EntityId;
                               var gun_jamming__fixJammingEndAt : float&;
                               var gun_jamming__fixJammingStartAt : float&;
                               var phys_vars : PhysVars;
                               var gun_jamming__isJammedClient : bool&)
  if gun_anim_v2__currentOperationState == int(GunOperationState.FIX_JAMMING)
    let progress = cvt(act.curTime, gun_jamming__fixJammingStartAt, gun_jamming__fixJammingEndAt, 0.0, 1.0)
    phys_vars |> setVar(gun_anim_v2__operationProgressVarId, progress)
    if progress >= 1.0
      gun_jamming__isJammedClient = false
      gun_jamming__fixJammingStartAt = -1.0
      gun_jamming__fixJammingEndAt = -1.0
      set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)


[es(track=isDowned)]
def fix_jamming_track_is_downed(evt : Event;
                                human_weap__currentGunEid : EntityId;
                                isDowned : bool)
  if isDowned
    abort_fix_jamming(human_weap__currentGunEid)


[es(on_disappear, REQUIRE=attachedToParent)]
def fix_jamming_track_is_weapon_in_hands(evt : Event; eid : EntityId)
  abort_fix_jamming(eid)


[es(track=gun__owner)]
def fix_jamming_track_weapon_dropped(evt : Event; eid, gun__owner : EntityId)
  if gun__owner == INVALID_ENTITY_ID
    abort_fix_jamming(eid)


[unused_argument(human_net_phys__isCrawl), es(track=human_net_phys__isCrawl)]
def fix_jamming_track_crawl(evt : Event;
                            human_weap__currentGunEid : EntityId;
                            human_net_phys__isCrawl : bool)
  abort_fix_jamming(human_weap__currentGunEid)


[es]
def fix_jamming_track_crawling(cmd : CmdPostPhysUpdate;
                               human_weap__currentGunEid : EntityId;
                               human_net_phys__isCrawl : bool;
                               human_net_phys : HumanActor)
  if human_net_phys__isCrawl && length_sq(human_net_phys.phys.currentState.velocity) > 0.0
    abort_fix_jamming(human_weap__currentGunEid)
