options no_aot
require ecs
require game.es.net_console_macro
require game.events.events_active_matter
require HumanPhys
require DngActor
require DngHuman
require DagorSystem


[net_console_cmd(name="teaser.enable_group")]
def console_teaser_enable_group(group : int;
                                enable : bool = true)
  query() <| $ [es] (teaser_bot__group : int;
                     var human_net_phys : HumanActor;
                     var beh_tree__enabled : bool&)
    if teaser_bot__group == group
      beh_tree__enabled = enable
      if !beh_tree__enabled
        human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, false)
        human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, false)


[net_console_cmd(name="teaser.resurrect_group")]
def console_teaser_resurrect_group(group : int)
  var groupEnabled = false
  find_query() <| $ [es] (teaser_bot__group : int;
                          beh_tree__enabled : bool)
    if teaser_bot__group == group
      if beh_tree__enabled
        groupEnabled = true
        return true
    return false

  query() <| $ [es] (eid : EntityId;
                     teaser_bot__group : int;
                     isAlive : bool;
                     teaser_bot__originTemplate : string;
                     teaser_bot__originTransform : float3x4;
                     teaser_bot__originPose : int)
    if teaser_bot__group == group
      if !isAlive
        createEntity(teaser_bot__originTemplate) <| $(var init)
          set(init, "transform", teaser_bot__originTransform)
          set(init, "teaser_bot__originPose", teaser_bot__originPose)
          set(init, "teaser_bot__group", teaser_bot__group)
          set(init, "beh_tree__enabled", groupEnabled)
        destroyEntity(eid)


[net_console_cmd(name="teaser.set_jump_dist")]
def console_teaser_set_jump_dist(dist : float)
  find_query() <| $ [es] (var final_euclid_teaser_params__jumpAimDist : float&)
    final_euclid_teaser_params__jumpAimDist = dist
    return false