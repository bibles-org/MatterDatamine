options always_export_initializer = true
require ecs
require ecs.safe
require app
require math
require math.base
require DagorRandom
require DagorMath
require Dacoll
require BehNodes
require game.events.events
require game.events.events_active_matter
require Grid
require DngDm
require DagorDataBlock
require DagorSystem
require danetlibs.swarm.main.swarm_events


def add_threat_to_list(income_threat : float3; var threats : Point3List; threat_replace_dist : float)
  var isReplaced = false
  for threat in threats
    if length_sq(threat - income_threat) <= square(threat_replace_dist)
      isReplaced = true
      threat = income_threat
  if !isReplaced
    threats |> push(income_threat)


[es(tag=server, no_order, REQUIRE=am_bees_guard_swarm)]
def am_bees_guards_util_vars(act : UpdateStageInfoAct;
                             swarm_cluster__serverCount, swarm_cluster__minHealthyCount : int;
                             swarm_cluster__target : EntityId;
                             swarm_cluster__targetPos : float3;
                             corpse_attached_swarm__detractUntil : float const?;
                             var util_vars__aggressionLevel : float&;
                             var util_vars__battleReady, util_vars__hasTargetToMove, util_vars__hasTargetToAttack, util_vars__ready : bool&)
  if util_vars__ready
    return

  util_vars__hasTargetToAttack = swarm_cluster__target != INVALID_ENTITY_ID
  util_vars__hasTargetToMove = swarm_cluster__targetPos |> length_sq() > 0f
  util_vars__aggressionLevel = util_vars__hasTargetToAttack ? 1f : saturate(util_vars__aggressionLevel - act.dt * 2f)

  util_vars__battleReady = swarm_cluster__serverCount >= swarm_cluster__minHealthyCount
  if corpse_attached_swarm__detractUntil != null && *corpse_attached_swarm__detractUntil > act.curTime
    util_vars__battleReady = false

  util_vars__ready = true


[es(tag=server, no_order)]
def am_bees_leader_update_state(act : UpdateStageInfoAct;
                                transform : float3x4;
                                am_bees_leader__nextUpdateInterval : float2;
                                var am_bees_leader__nextUpdateAt : float&;
                                var am_bees_leader__positionHistory : float3&;
                                var am_bees_leader__leaderSwarmEid : EntityId&)
  if act.curTime < am_bees_leader__nextUpdateAt
    return
  let interval = rnd_float(am_bees_leader__nextUpdateInterval.x, am_bees_leader__nextUpdateInterval.y)
  am_bees_leader__nextUpdateAt = act.curTime + interval
  am_bees_leader__positionHistory = transform[3]
  query(am_bees_leader__leaderSwarmEid) <| $ [es] (swarm_cluster__target : EntityId;
                                                   var am_bees_leader__isFollowed : bool&)
    if !swarm_cluster__target
      am_bees_leader__leaderSwarmEid = INVALID_ENTITY_ID
      am_bees_leader__isFollowed = false


[es]
def set_boids_stamina_for_swarm(evt : CmdSetBoidsStamina;
                                eid : EntityId;
                                transform : float3x4;
                                swarm_cluster__velocity : float3)
  query() <| $ [es] (parentSwarm : EntityId;
                     position : float3;
                     var boidStamina : float&)
    if parentSwarm == eid
      let toBoidDir = position - transform[3]
      let distToCenter = length(toBoidDir)
      let boidDot = dot(normalize(toBoidDir), normalize(swarm_cluster__velocity))
      boidStamina = max(0.1f, min(2f, boidDot + 1f / (0.1 + distToCenter)))


[es(tag=server, on_appear, REQUIRE=am_bees_solo_swarm)]
def am_bees_solo_create(evt : Event;
                        transform : float3x4;
                        var swarm_cluster__hivePos : float3&)
  swarm_cluster__hivePos = transform[3]

[es(tag=server, no_order, REQUIRE=am_bees_solo_swarm)]
def am_bees_solo_util_vars(act : UpdateStageInfoAct;
                           swarm_cluster__serverCount, swarm_cluster__minHealthyCount : int;
                           swarm__hitTargets : Array;
                           swarm__retired : bool;
                           swarm_cluster__hivePos : float3;
                           transform aka swarm_transform : float3x4;
                           swarm_cluster__maxDistanceFromHive, aggressive_swarm__aggressionLevel : float;
                           attract_point__eid : EntityId;
                           swarm_cluster__hearingRange : float;
                           var util_vars__distanceFromHive, util_vars__aggressionLevel : float&;
                           var util_vars__battleReady, util_vars__retired, util_vars__hasTargetToAttack, util_vars__hasPointsToInvestigate, util_vars__ready : bool&)
  if util_vars__ready
    return

  util_vars__distanceFromHive = safediv(length(swarm_transform[3] - swarm_cluster__hivePos), swarm_cluster__maxDistanceFromHive)
  util_vars__battleReady = swarm_cluster__serverCount >= swarm_cluster__minHealthyCount

  util_vars__hasPointsToInvestigate = false
  query(attract_point__eid) <| $ [es] (transform : float3x4)
    util_vars__hasPointsToInvestigate = (
         attract_point__eid |> has("smellAttractPoint")
      || distance_sq(transform[3], swarm_transform[3]) <= square(swarm_cluster__hearingRange)
    )
  util_vars__retired = swarm__retired
  util_vars__hasTargetToAttack = swarm__hitTargets |> length() > 0
  util_vars__aggressionLevel = aggressive_swarm__aggressionLevel

  util_vars__ready = true


[beh_node(name="isBeesInHive")]
class IsBeesInHive : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4; swarm_cluster__hivePos : float3)
      if length_sq(transform[3] - swarm_cluster__hivePos) < square(3.0)
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="beesSwarmShoot")]
class BeesSwarmShoot : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (swarm__hitTargets : Array;
                               shooting_swarm__shootShellsCountRng : int2;
                               shooting_swarm__shootFreqRng : float2;
                               shooting_swarm__shellTemplate : string;
                               shooting_swarm__shellSpeed : float;
                               transform : float3x4;
                               var shooting_swarm__nextShootAt : float&)
      if get_sync_time() >= shooting_swarm__nextShootAt
        shooting_swarm__nextShootAt = get_sync_time() + rnd_float(shooting_swarm__shootFreqRng.x, shooting_swarm__shootFreqRng.y)
        if length(swarm__hitTargets) > 0
          var visibleTargets : array<float3>
          for it in swarm__hitTargets
            let data = it as Object
            if data?.visible ?? false
              let victimPos = data?.pos ?as float3
              if victimPos != null
                visibleTargets |> push(*victimPos)

          if length(visibleTargets) > 0
            let shellsCount = rnd_int(shooting_swarm__shootShellsCountRng.x, shooting_swarm__shootShellsCountRng.y)
            for _, target in range(shellsCount), visibleTargets
              createEntity(shooting_swarm__shellTemplate) <| $(var initObj)
                initObj |> set("xvp_bees_shell__target", target)
                initObj |> set("transform", transform)
                initObj |> set("xvp_bees_shell_owner", agentEid)
                initObj |> set("position", transform[3] + float3(0f, 300f, 0f))
                initObj |> set("xvp_bees_shell__velocity", normalize(target - transform[3]))
                initObj |> set("xvp_bees_shell__speed", shooting_swarm__shellSpeed)
                initObj |> set("game_effect__timeToDestroy", (distance(target, transform[3]) / shooting_swarm__shellSpeed) + 2f)
          result = EBehResult.ER_SUCCESS
    return result
