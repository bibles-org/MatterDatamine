from "team" import TEAM_UNASSIGNED
from "matching.errors" import INVALID_SQUAD_ID
from "net" import get_user_id
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let logObs = require("%sqGlob/library_logs.nut").with_prefix("[OBSERVER]")

const INVALID_USER_ID = 0

let localPlayerUserId = mkWatched(persist, "localPlayerUserId", INVALID_USER_ID)
let localPlayerEid = mkWatched(persist, "localPlayerEid", ecs.INVALID_ENTITY_ID)
let localPlayerSpecTarget = mkWatched(persist, "localPlayerSpecTarget", ecs.INVALID_ENTITY_ID)
const UNDEFINEDNAME = "?????"
let localPlayerName = mkWatched(persist, "localPlayerName", UNDEFINEDNAME)
let localPlayerTeam = mkWatched(persist, "localPlayerTeam", TEAM_UNASSIGNED)
let localPlayerTeamEid = mkWatched(persist, "localPlayerTeamEid", ecs.INVALID_ENTITY_ID)
let localPlayerTeamIsIncognito = mkWatched(persist, "localPlayerTeamIsIncognito", false)
let localPlayerGroupId = mkWatched(persist, "localPlayerGroupId", INVALID_SQUAD_ID)
let localPlayerGroupMembers = mkWatched(persist, "localPlayerGroupMembers", {})
let groupmateQuery = ecs.SqQuery("groupmateQuery", {comps_ro = [["groupId", ecs.TYPE_INT64]]})

localPlayerSpecTarget.subscribe(@(eid) logObs($"spectated: {eid}"))

function addGroupmate(eid, comp) {
  if (comp["groupId"] == localPlayerGroupId.get()) {
    if (eid in localPlayerGroupMembers.get())
      return
    localPlayerGroupMembers.mutate(@(v) v[eid] <- true)
  }
}

function resetData() {
  localPlayerEid.set(ecs.INVALID_ENTITY_ID)
  localPlayerTeam.set(TEAM_UNASSIGNED)
  localPlayerTeamEid.set(ecs.INVALID_ENTITY_ID)
  localPlayerUserId.set(get_user_id())
  localPlayerSpecTarget.set(ecs.INVALID_ENTITY_ID)
  localPlayerGroupId.set(INVALID_SQUAD_ID)
}

function trackComponents(_evt, eid, comp) {
  if (comp.is_local) {
    localPlayerEid.set(eid)
    localPlayerTeam.set(comp.team)
    localPlayerTeamEid.set(comp.player__teamEid)
    localPlayerName.set(comp.name)
    localPlayerUserId.set(get_user_id())
    localPlayerSpecTarget.set(comp.specTarget)
    localPlayerGroupId.set(comp.groupId)
    groupmateQuery.perform(addGroupmate)
  } else if (localPlayerEid.get() == eid) {
    resetData()
  }
}

function onDestroy(_evt, eid, _comp) {
  if (localPlayerEid.get() == eid)
    resetData()
}

ecs.register_es("local_player_es", {
    onChange = trackComponents
    onInit = trackComponents
    onDestroy = onDestroy
  },
  {
    comps_track = [
      ["is_local", ecs.TYPE_BOOL],
      ["team", ecs.TYPE_INT],
      ["player__teamEid", ecs.TYPE_EID],
      ["name", ecs.TYPE_STRING],
      ["specTarget", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
      ["groupId", ecs.TYPE_INT64]
    ]
    comps_rq = ["player"]
  }
)

ecs.register_es("local_player_group_es",
  {
    [["onInit"]] = @ (_, eid, comp) addGroupmate(eid, comp)
    onDestroy = function (_evt, eid, _comp) {
      if (eid in localPlayerGroupMembers.get())
        localPlayerGroupMembers.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {comps_ro = [["groupId", ecs.TYPE_INT64]]}
)

let localPlayerTeamParamsQuery = ecs.SqQuery("localPlayerTeamParamsQuery",  {
  comps_ro = [
    ["team__id", ecs.TYPE_INT],
    ["team__incognito", ecs.TYPE_TAG, null]
  ]
})

localPlayerTeamEid.subscribe_with_nasty_disregard_of_frp_update(function(val) {
  if (val == ecs.INVALID_ENTITY_ID) {
    localPlayerTeamIsIncognito.set(false)
    return
  }

  localPlayerTeamParamsQuery.perform(val, function(_eid, comp) {
    localPlayerTeamIsIncognito.set(comp.team__incognito != null)
  })
})

return {
  localPlayerName
  localPlayerEid
  localPlayerTeam
  localPlayerTeamEid
  localPlayerTeamIsIncognito
  localPlayerUserId
  localPlayerSpecTarget
  localPlayerGroupId
  localPlayerGroupMembers
}