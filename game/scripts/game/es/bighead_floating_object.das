require ecs
require DagorMath
require math.base
require game.events.events_active_matter
require app
require DngPhysObj
require game.events.events
require DngWeapon
require DaWeaponProps
require NetPropsRegistry
require DngDm
require Grid
require net
require math.random
require game.es.bighead_common
require DngNet


[es(before=floating_object_set_position, REQUIRE_NOT=floating_object__disableEllipseFloating)]
def floating_object_move(update : ParallelUpdateFrameDelayed;
                         floating_object__speed : float;
                         var floating_object__currentEllipseParam : float&)
  floating_object__currentEllipseParam = floating_object__speed * update.curTime


[es(no_order, REQUIRE_NOT=bighead_floating_object_attack_launched__position)]
def floating_object_prepare_attack(update : ParallelUpdateFrameDelayed;
                                   bighead_floating_object_attack__preparePosition : float3;
                                   bighead_floating_object_attack__prepareMoveSpeed : float;
                                   var transform aka object_transform : float3x4)
  let vector = bighead_floating_object_attack__preparePosition - object_transform[3]
  object_transform[3] += vector * bighead_floating_object_attack__prepareMoveSpeed * update.dt


[es(on_appear, tag=server, REQUIRE=bighead_floating_object_attack__preparePosition)]
def bighead_floating_object_prepare_attack_init(evt : Event;
                                                floating_object__owner : EntityId;
                                                floating_object__ellipseHeight : float;
                                                floating_object__ellipseWidth : float;
                                                floating_object__currentEllipseParam : float;
                                                floating_object__orbitAngle : float;
                                                var transform aka object_transform : float3x4)
  query(floating_object__owner) <| $ [es] (transform aka owner_transform : float3x4)
    object_transform[3] = calc_floating_object_ellipse_position(floating_object__ellipseHeight,
                                                                        floating_object__ellipseWidth,
                                                                        floating_object__currentEllipseParam,
                                                                        floating_object__orbitAngle,
                                                                        owner_transform[3])


[es(tag=server)]
def floating_object_attack_launch(evt : CmdLaunchBigheadProjectile;
                                  eid : EntityId;
                                  floating_object__owner : EntityId;
                                  bighead_floating_object_attack__target : EntityId)
  query(bighead_floating_object_attack__target) <| $ [es] (transform : float3x4)
    query(floating_object__owner) <| $ [es] (floating_objects__eids : EidList)
      using() <| $(var toIgnore : EidList)
        for obj in floating_objects__eids
          push(toIgnore, obj)
        toIgnore |> push(eid)
        let initNetPhys <- @ <| (reid : EntityId; var cInit : ComponentsInitializer)
          let net__physId = get_int(reid, "net__physId")
          if net__physId != null
            set(cInit, "net__physId", *net__physId) // transfer just created physobj's physId to remote systems
        remote_add_sub_template(eid, "bighead_floating_object_attack_launched", initNetPhys) <| $(init)
          set(init, "bighead_floating_object_attack_launched__position", transform[3])


[es(on_appear)]
def floating_object_attack_launch_init(evt : Event;
                                       bighead_floating_object_attack_launched__position : float3;
                                       bighead_floating_object_attack_launched__speed : float;
                                       var phys_obj_net_phys : PhysObjActor;
                                       transform : float3x4)
  let direction = normalize(bighead_floating_object_attack_launched__position - transform[3])
  let velocity = direction * bighead_floating_object_attack_launched__speed
  phys_obj_net_phys.phys.currentState.velocity = velocity


[es(on_appear, REQUIRE=floating_object__owner)]
def init_floating_object_shell_props(evt : Event;
                                     phys_obj_net_phys__blk : string;
                                     var shell__shell_id__ballistics_id : int&;
                                     var shell__shell_id__damage_id : int&;
                                     var shell__shell_id__shell_id : int&)
  shell__shell_id__ballistics_id = register_net_props(phys_obj_net_phys__blk, "shell")
  shell__shell_id__damage_id = register_net_props(phys_obj_net_phys__blk, "damage")
  shell__shell_id__shell_id = register_net_props(phys_obj_net_phys__blk, "ballistics")


[es(tag=server)]
def floating_object_attack_launch_on_contact(evt : EventFirstContact;
                                             shell__shell_id__shell_id : int;
                                             shell__shell_id__damage_id : int;
                                             shell__shell_id__ballistics_id : int;
                                             floating_object__owner : EntityId;
                                             floating_object_launched__downChance : float;
                                             floating_object_launched__downDuration : float;
                                             phys_obj_net_phys : PhysObjActor;
                                             eid : EntityId)
  destroyEntity(eid)
  using() <| $(var shellId : ShellPropIds#)
    shellId.shellId = int16(shell__shell_id__shell_id)
    shellId.damageId = int16(shell__shell_id__damage_id)
    shellId.ballisticsId = int16(shell__shell_id__ballistics_id)
    assume velocity = phys_obj_net_phys.phys.currentState.velocity
    let pos = float3(phys_obj_net_phys.phys.currentState.location.P)

    let normal = float3()
    detonate_shell_server(eid, shellId, -1, pos,
                          floating_object__owner, pos,
                          velocity, floating_object__owner,
                          normal, INVALID_ENTITY_ID)
    let maxRadius = get_shell_max_radius(shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id)
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, maxRadius), GridEntCheck.BOUNDING) <| $(militantEid : EntityId)
      if gfrnd() < floating_object_launched__downChance
        send_net_event(militantEid, EventHumanFall(duration = floating_object_launched__downDuration))



[es(before=floating_object_move)]
def bighead_floating_object_delayed_destruction(update : ParallelUpdateFrameDelayed;
                                                eid : EntityId;
                                                bighead_floating_object_destruction__destroyAt : float;
                                                bighead_floating_object_destruction__stoppingViscosity : float;
                                                var euler_sinusoidal_oscillation__amplitude : float3&;
                                                var floating_object__speed : float&)
  floating_object__speed = approach(floating_object__speed, 0.0, update.dt, bighead_floating_object_destruction__stoppingViscosity)
  euler_sinusoidal_oscillation__amplitude = approach(euler_sinusoidal_oscillation__amplitude, float3(0.0), update.dt, bighead_floating_object_destruction__stoppingViscosity)
  if get_sync_time() > bighead_floating_object_destruction__destroyAt
    destroyEntity(eid)


[es(before=euler_sinusoidal_oscillation_update, REQUIRE_NOT=floating_object__disableEllipseFloating, tag=gameClient)]
def floating_object_set_position(update : ParallelUpdateFrameDelayed;
                                 floating_object__owner : EntityId;
                                 floating_object__ellipseHeight : float;
                                 floating_object__ellipseWidth : float;
                                 floating_object__currentEllipseParam : float;
                                 floating_object__orbitAngle : float;
                                 var transform aka object_transform : float3x4&)
  query(floating_object__owner) <| $ [es] (floating_objects__anchorPosition : float3)
    object_transform[3] = calc_floating_object_ellipse_position(floating_object__ellipseHeight,
                                                                        floating_object__ellipseWidth,
                                                                        floating_object__currentEllipseParam,
                                                                        floating_object__orbitAngle,
                                                                        floating_objects__anchorPosition)