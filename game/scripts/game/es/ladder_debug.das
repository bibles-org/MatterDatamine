options no_aot
require ecs
require game.es.net_console_macro
require game.events.events
require DngHuman
require DagorSystem

[net_console_cmd(name="ladder.debug")]
def ladder_debug(@net_hero eid : EntityId)
  if eid |> has("ladderDebug")
    remote_remove_sub_template(eid, "ladder_debug")
  else
    remote_add_sub_template(eid, "ladder_debug")


[es(REQUIRE=ladderDebug)]
def ladder_debug_print_state(evt : CmdPostPhysUpdate;
                             eid : EntityId;
                             human_ladder__attached : bool;
                             human_ladder__detached : bool;
                             human_ladder__pull : bool;
                             human_net_phys : HumanActor)
  let physAttached = human_net_phys.phys.currentState.isAttachedToLadder
  if !human_ladder__attached && !human_ladder__detached && !human_ladder__pull && !physAttached
    return

  print("[LADDER DEBUG] {eid} is attached: {human_ladder__attached}, detached: {human_ladder__detached}, pull: {human_ladder__pull}, physAttached: {physAttached}")

  var ladderTm = human_net_phys.phys.currentState.ladderTm
  let ladderOffset = human_net_phys.phys.collRad + length(ladderTm[0])
  ladderTm |> orthonormalize()

  let heroPos = float3(human_net_phys.phys.currentState.location.P)
  let localPos = inverse(ladderTm) * heroPos
  let onLadderPos = ladderTm * float3(ladderOffset, localPos.y, localPos.z)

  print("[LADDER DEBUG] ({evt.tick}) heroPos = {heroPos} ; localPos = {localPos} ; onLadderPos = {onLadderPos}")
  print("[LADDER DEBUG] ladderTm[0] = {ladderTm[0]}")

  print("[LADDER DEBUG] prevAngles = {human_net_phys.phys.currentState.prevAngles} -> gunAngles = {human_net_phys.phys.currentState.gunAngles} ; gunDir = {human_net_phys.phys.currentState.gunDir}" +
        " ; gunSpd = {human_net_phys.phys.currentState.gunSpd} ; targetGunSpd = {human_net_phys.phys.currentState.targetGunSpd} ; wishShootDir = {human_net_phys.phys.appliedCT.wishShootDir}")