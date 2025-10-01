from "%sqstd/string.nut" import floatToStringRounded

from "%ui/ui_library.nut" import max
from "dagor.math" import Point3

let { Computed } = require("%ui/ui_library.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { playerPath } = require("%ui/mainMenu/debriefing/debriefing_player_path_state.nut")
let { journalBattleResult } = require("%ui/profile/battle_results.nut")

let calcSegmentLength = @(segment, all_points) all_points.slice(segment[0], segment[1]).reduce(function(acc, point, i) {
  let curPoint = Point3(point.position.x, point.position.y, point.position.z)
  if (i == 0)
    return {prev = curPoint, dist = 0}

  return {
    prev = curPoint,
    dist = acc.dist + (curPoint - acc.prev).length()
  }
}, {})?.dist ?? 0.0

let debriefingStatsCalculated = Computed(function() {
  if (!isOnPlayerBase.get()
    || playerPath.get() == null
    || (lastBattleResult.get() == null && journalBattleResult.get() == null)
    || journalBattleResult.get()?.isNexus
  )
    return null

  let battleResult = journalBattleResult.get() ?? lastBattleResult.get()
  let stats = battleResult.debriefingStatsV2
  let trackPoints = battleResult.trackPoints

  return {
    distance_traveled = floatToStringRounded(playerPath.get().pathSegmentIndices.reduce(
      @(acc, segment) acc + calcSegmentLength(segment, trackPoints),
      0
    ), 0.1),
    max_height = floatToStringRounded(
                    trackPoints.reduce(@(m, v) m = max(v.position.y, m), -1000),
                    0.1),
    points_of_interest_visited = trackPoints.filter(@(v) v.eventType == "encounterVisit").len(),

    contracts_completed = -1,
    containers_looted = stats.lootedCommonContainers,
    bodies_looted = stats.lootedBodies,
    secret_stashes_found = stats.lootedSecretContainers,

    enemies_killed = trackPoints.filter(@(v) v.eventType == "kill").len(),
    damage_dealt = floatToStringRounded(stats.dealtDamage, 1.0),
    damage_taken = floatToStringRounded(stats.receivedDamage, 1.0),
    medicine_used = stats.medicineUsed,

    daily_rewards = battleResult?.dailyStatRewards ?? {}
  }
})

return {
  debriefingStatsCalculated
}
