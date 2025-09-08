options always_export_initializer = true
require ecs
require ecs.common
require app
require net
require math.base
require game.utils.team
require game.es.nexus_common
require game.es.nexus_beacon_common
require game.es.nexus_round_mode_common
require game.events.events_active_matter
require game.events.events
require DagorDataBlock
require BehNodes
require DagorRandom


[beh_node(name="isNexusRoundStarted")]
class IsNexusRoundStarted : BehNodeAdapter
  def override update(dt : float) : EBehResult
    return is_round_state(NexusRoundState.Started) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findNexusBaseToCapture")]
class FindNexusBaseToCapture : BehNodeAdapter
  outParamId : int

  def override loadFromBlk(var data : DataBlock) : void
    let paramName = datablock_getStr(data, "outParamName", "")
    outParamId = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (team : int; transform aka agent_transform : float3x4)
      var possibleBases : array<tuple<eid : EntityId; isCaptured : bool; controlledByTeam : int; distanceSq : float>>
      var areThereNotOurBases = false
      query() <| $ [es(REQUIRE=nexus_beacon)] (nexus_beacon__captureDevices : EidList;
                                               nexus_beacon__state : int;
                                               nexus_beacon__controllingTeam : int)
        let isCaptured = nexus_beacon__state == int(NexusBeaconState.CAPTURED)
        assume controlledByTeam = nexus_beacon__controllingTeam

        if areThereNotOurBases && controlledByTeam == team && isCaptured
          return

        if !isCaptured || controlledByTeam != team
          areThereNotOurBases = true

        for captureDevice in nexus_beacon__captureDevices
          query(captureDevice) <| $ [es] (transform aka nexus_beacon_capture_device_transform : float3x4)
            assume distSq = distance_sq(agent_transform[3], nexus_beacon_capture_device_transform[3])
            emplace(possibleBases, (captureDevice, isCaptured, controlledByTeam, distSq))

      if areThereNotOurBases
        // filter out our bases, others are way more important
        let originalLen = length(possibleBases)
        for i in range(originalLen)
          let revIdx = originalLen - i - 1
          if possibleBases[revIdx].isCaptured && possibleBases[revIdx].controlledByTeam == team
            erase(possibleBases, revIdx)

      sort(possibleBases) <| $(first, second)
        assume firstIsAlreadyOurs = first.isCaptured && first.controlledByTeam == team
        assume secondIsAlreadyOurs = second.isCaptured && second.controlledByTeam == team
        if firstIsAlreadyOurs != secondIsAlreadyOurs
          // want better bases to be closer to first spot
          // so if first base is ours, we should return false
          // and vice versa
          return secondIsAlreadyOurs

        if firstIsAlreadyOurs
          // if both bases are ours, we want the one that is closer to us
          return first.distanceSq < second.distanceSq

        if first.controlledByTeam != second.controlledByTeam
          // if one of the bases is being captured by us
          // push it away from the front
          if first.controlledByTeam == team
            return false
          if second.controlledByTeam == team
            return true

          // both teams are not ours, but different
          // means one of them is held by the enemy, choose it
          return first.controlledByTeam != TEAM_UNASSIGNED

        return first.distanceSq < second.distanceSq

      if empty(possibleBases)
        return

      let idx1 = rnd_int(0, length(possibleBases) - 1)
      let idx2 = rnd_int(0, length(possibleBases) - 1)
      // bases closer to start have higher probability to be chosen
      let idx = min(idx1, idx2)
      let chosenBase = possibleBases[idx].eid
      owner.blackBoard |> set(outParamId, int(uint(chosenBase)))
      res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="isNexusBaseFriendlyCaptured")]
class IsNexusBaseFriendlyCaptured : BehNodeAdapter
  targetBaseParam : int
  targetEid : EntityId
  ownerTeam : int

  def override loadFromBlk(var data : DataBlock) : void
    let paramName = datablock_getStr(data, "targetBase", "")
    targetBaseParam = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override init() : void
    targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetBaseParam)))
    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      ownerTeam = team

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(targetEid) <| $ [es] (nexus_beacon_capture_device__beacon : EntityId)
      query(nexus_beacon_capture_device__beacon) <| $ [es] (nexus_beacon__state : int;
                                                            nexus_beacon__controllingTeam : int)
        let channelingFinished = nexus_beacon__state == int(NexusBeaconState.CAPTURED) && nexus_beacon__controllingTeam == ownerTeam
        if channelingFinished
          res = EBehResult.ER_SUCCESS
          return
    return res


[beh_node(name="captureNexusBase")]
class CaptureNexusBase : BehNodeAdapter
  targetBaseParam : int
  targetEid : EntityId
  ownerTeam : int

  def override loadFromBlk(var data : DataBlock) : void
    let paramName = datablock_getStr(data, "targetBase", "")
    targetBaseParam = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override init() : void
    targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetBaseParam)))
    sendEventImmediate(targetEid, CmdUse(requesterEid = beh_tree_eid(owner)))
    query(beh_tree_eid(owner)) <| $ [es] (team : int)
      ownerTeam = team

  def override exit() : void
    send_net_event(beh_tree_eid(owner), RequestNexusStopCapturingBeacon(beaconEid = targetEid))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(targetEid) <| $ [es] (nexus_beacon_capture_device__beacon : EntityId;
                                nexus_beacon_capture_device__capturingMilitant : EntityId)
      query(nexus_beacon_capture_device__beacon) <| $ [es] (nexus_beacon__state : int;
                                                            nexus_beacon__controllingTeam : int)
        let channelingFinished = nexus_beacon__state == int(NexusBeaconState.CAPTURED) && nexus_beacon__controllingTeam == ownerTeam
        if channelingFinished
          res = EBehResult.ER_SUCCESS
          return

        let isStillChanneling = nexus_beacon_capture_device__capturingMilitant == ownerEid
        if isStillChanneling
          res = EBehResult.ER_RUNNING
          return
    return res


[beh_node(name="nexusChooseTeammateToFollow")]
class NexusChooseTeammateToFollow : BehNodeAdapter
  outParamId : int

  def override loadFromBlk(var data : DataBlock) : void
    let paramName = datablock_getStr(data, "outParamName", "")
    outParamId = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (team aka owner_team : int;
                               transform aka owner_transform : float3x4;
                               nexus_militant_round_mode_bot__maxDistanceToStartFollowing : float)
      if team == TEAM_UNASSIGNED
        return

      let maxDistSq = square(nexus_militant_round_mode_bot__maxDistanceToStartFollowing)
      var bestCandidate = INVALID_ENTITY_ID
      var bestCandidateDistSq = FLT_MAX
      query() <| $ [es(REQUIRE_NOT=(beh_tree, deadEntity))] (eid : EntityId;
                                                             transform aka other_transform : float3x4;
                                                             team aka other_team : int;
                                                             nexus_round_mode_militant__followedBy : EidList;
                                                             nexus_round_mode_militant__maxFollowers : int)
        if other_team != owner_team || eid == ownerEid
          return

        if length(nexus_round_mode_militant__followedBy) >= nexus_round_mode_militant__maxFollowers
          return

        let distSq = distance_sq(owner_transform[3], other_transform[3])
        if distSq > maxDistSq
          return

        if distSq < bestCandidateDistSq
          bestCandidateDistSq = distSq
          bestCandidate = eid

      query(bestCandidate) <| $ [es] (var nexus_round_mode_militant__followedBy : EidList)
        push(nexus_round_mode_militant__followedBy, ownerEid)
        owner.blackBoard |> set(outParamId, int(uint(bestCandidate)))
        res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="nexusStopFollowingTeammate")]
class NexusStopFollowingTeammate : BehNodeAdapter
  paramId : int

  def override loadFromBlk(var data : DataBlock) : void
    let paramName = datablock_getStr(data, "teammateParam", "")
    paramId = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    let teammate = EntityId(uint(owner.blackBoard |> datablock_getInt(paramId)))
    var res = EBehResult.ER_FAILED
    query(teammate) <| $ [es] (var nexus_round_mode_militant__followedBy : EidList)
      let ownerEid = beh_tree_eid(owner)
      let idx = find_index(nexus_round_mode_militant__followedBy, ownerEid)
      if idx < 0
        res = EBehResult.ER_FAILED
        return

      erase(nexus_round_mode_militant__followedBy, idx)
      res = EBehResult.ER_SUCCESS
    return res
