require ecs
require math
require math.base
require DagorMath
require DngPhysObj
require game.events.events
require DaWeaponProps
require game.events.events_game


def explode_shell(eid : EntityId;
                  curTime : float;
                  phys_obj_net_phys : PhysObjActor;
                  var shell__active : bool&;
                  var shell__launchTime : float&;
                  shell__fuseTime : float;
                  shell__cleanupTime : float)
  shell__active = false
  if curTime >= shell__launchTime + shell__fuseTime
    let prevPos = float3(phys_obj_net_phys.phys.previousState.location.P)
    // use previous state because current velocity might be already clipped
    let vel = phys_obj_net_phys.phys.previousState.velocity
    sendEvent(eid, CmdShellExplode(position = phys_obj_net_phys.phys.currentState.contactPoint, prevPos = prevPos, vel = vel))
  else
    sendEvent(eid, CmdBodyCleanup(time = shell__cleanupTime))

[es(REQUIRE=shell__explodeOnContact)]
def explode_on_contact_shell_contact(evt : CmdPostPhysUpdate;
                                     eid : EntityId;
                                     phys_obj_net_phys : PhysObjActor;
                                     var shell__active : bool&;
                                     var shell__launchTime : float&;
                                     shell__fuseTime : float = 0.0;
                                     shell__cleanupTime : float = 5.0)
  if !shell__active
    return
  let curTime = float(evt.tick) * evt.dt
  if shell__launchTime < 0.0
    shell__launchTime = curTime
  if !phys_obj_net_phys.phys.currentState.hadContact
    return
  explode_shell(eid, curTime, phys_obj_net_phys, shell__active, shell__launchTime, shell__fuseTime, shell__cleanupTime)


[es(REQUIRE=shell__explodeOnSpeedDrop)]
def explode_on_speed_drop_shell_contact(evt : CmdPostPhysUpdate;
                                        eid : EntityId;
                                        phys_obj_net_phys : PhysObjActor;
                                        shell__shell_id__shell_id : int;
                                        shell__activationSpeedDropThreshold : float;
                                        var shell__active : bool&;
                                        var shell__launchTime : float&;
                                        shell__fuseTime : float = 0.0;
                                        shell__cleanupTime : float = 5.0)
  if !shell__active
    return

  let curTime = float(evt.tick) * evt.dt
  if shell__launchTime < 0.f
    shell__launchTime = curTime
  if !phys_obj_net_phys.phys.currentState.hadContact
    return
  if phys_obj_net_phys.phys.hasRiDestroyingCollision
    return

  let vel = phys_obj_net_phys.phys.currentState.velocity
  shell_start_get_props(shell__shell_id__shell_id) <| $(startProps : ShellStartProps)
    if safediv(length(vel), startProps.speed) >= shell__activationSpeedDropThreshold
      return

    explode_shell(eid, curTime, phys_obj_net_phys, shell__active, shell__launchTime, shell__fuseTime, shell__cleanupTime)
