require ecs
require game.events.vehicle_events
require DagorSystem


[es(tag=server, after=repair_es)]
def anim_for_repair_create(evt : CmdStartRepair;
                           eid : EntityId;
                           repair__active : bool;
                           repair__animTempl : string;
                           var repair__animEid : EntityId&)
  if !repair__active
    return
  repair__animEid = createEntity(repair__animTempl) <| $(var init : ComponentsInitializer)
    set(init, "game_effect__attachedTo", eid)


[es(tag=server)]
def stop_anim_for_repair(evt : CmdStopRepair;
                         var repair__animEid : EntityId&)
  if repair__animEid != INVALID_ENTITY_ID
    destroyEntity(repair__animEid)
    repair__animEid = INVALID_ENTITY_ID
