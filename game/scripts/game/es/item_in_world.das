require ecs
require DngPhysObj
require DngNet
require game.events.events_active_matter


[es(tag=server, on_appear)]
def init_item_in_world_transform_server(evt : Event; transform : float3x4; var server_transform : float3x4)
  server_transform := transform


[es(tag=server, no_order, REQUIRE=item_in_world_phys)]
def item_in_world_phys_transform_server(act : UpdateStageInfoAct;
                                        transform : float3x4;
                                        var server_transform : float3x4)
  server_transform := transform


[es(tag=server, no_order, REQUIRE=server_transform_from_transform)]
def server_transform_from_transform(act : UpdateStageInfoAct;
                                    transform : float3x4;
                                    var server_transform : float3x4)
  server_transform := transform


[es(tag=server, on_appear)]
def init_item_in_world_phys(evt : Event;
                            phys_obj_net_phys : PhysObjActor;
                            var item_in_world_phys__isAsleep : bool&)
  item_in_world_phys__isAsleep = phys_obj_net_phys.isAsleep


[es(no_order, REQUIRE=item_in_world_phys)]
def item_in_world_phys_animchar(act : UpdateStageInfoAct;
                                phys_obj_net_phys : PhysObjActor;
                                var animchar__updatable : bool&)
  animchar__updatable = !phys_obj_net_phys.isAsleep


[es(tag=server, no_order)]
def item_in_world_phys_update(act : UpdateStageInfoAct;
                              eid : EntityId;
                              phys_obj_net_phys : PhysObjActor;
                              var item_in_world_phys__isAsleep : bool&)
  if item_in_world_phys__isAsleep != phys_obj_net_phys.isAsleep
    item_in_world_phys__isAsleep = phys_obj_net_phys.isAsleep
    send_net_event(eid, CmdStopItemInWorldPhys())


[es(tag=server, REQUIRE=item_in_world, REQUIRE_NOT=item_in_world_phys)]
def start_item_in_world_phys(evt : CmdStartItemInWorldPhys;
                             eid : EntityId;
                             item__recreateInWorldPhys : string;
                             item__recreateOnGround : string)
  if !empty(item__recreateInWorldPhys) && !empty(item__recreateOnGround)

    var templateName = add_sub_template_name(eid, item__recreateInWorldPhys)
    templateName = remove_sub_template_name(templateName, item__recreateOnGround)
    let initNetPhys <- @ <| (reid : EntityId;
                             var cInit : ComponentsInitializer)
      let net__physId = get_int(reid, "net__physId")
      if net__physId != null
        set(cInit, "net__physId", *net__physId) // transfer just created physobj's physId to remote systems
    remote_recreate_entity_from(eid, templateName, initNetPhys) <| $ [unused_argument(init)] (var init : ComponentsInitializer) {}


[es(REQUIRE=item_in_world_phys)]
def stop_item_in_world_phys(evt : CmdStopItemInWorldPhys;
                            eid : EntityId;
                            item__recreateInWorldPhys : string;
                            item__recreateOnGround : string)
  if !empty(item__recreateInWorldPhys) && !empty(item__recreateOnGround)
    eid |> removeSubTemplate(item__recreateInWorldPhys)
    eid |> addSubTemplate(item__recreateOnGround) <| $(init)
      init |> set("displacement_compensation__compensationTime", 0.15) // Workaround fix for item displacement compensation