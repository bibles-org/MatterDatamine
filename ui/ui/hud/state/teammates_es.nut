from "%ui/helpers/ec_to_watched.nut" import mkWatchedSetAndStorage
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { localPlayerTeam,
      localPlayerGroupId,
      localPlayerTeamIsIncognito
    } = require("%ui/hud/state/local_player.nut")


let {
  teammatesSet,
  teammatesGetWatched,
  teammatesUpdateEid,
  teammatesDestroyEid
} = mkWatchedSetAndStorage("teammates")

let {
  groupmatesSet,
  groupmatesGetWatched,
  groupmatesUpdateEid,
  groupmatesDestroyEid
} = mkWatchedSetAndStorage("groupmates")


function defComp_ctr(key, comp){
  if (type(comp?[key])=="instance")
    return comp?[key]?.getAll()
  return comp?[key]
}


let teammatesTrackComps = [
  ["team", ecs.TYPE_INT],
  ["isAlive", ecs.TYPE_BOOL],
  ["isDowned", ecs.TYPE_BOOL],
  ["possessedByPlr", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["human_weap__gunEids", ecs.TYPE_EID_LIST, {}],
  ["human_weap__currentGunEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["watchedByPlr", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID]
]

let teammates_get_name_query = ecs.SqQuery("teammates_get_name_query", {
  comps_ro = [["name", ecs.TYPE_STRING]]
})

let teammatesQuery = ecs.SqQuery("teammates_status_ui_query", {
  comps_ro = teammatesTrackComps
})

function updateTeammatesStatus(eid, comp) {
  if (localPlayerTeam.get() != comp["team"]
    || (localPlayerTeamIsIncognito.get() && comp.watchedByPlr == ecs.INVALID_ENTITY_ID)
  ) {
    teammatesDestroyEid(eid)
    return
  }
  let res = {}
  foreach (i in teammatesTrackComps)
    res[i[0]] <- defComp_ctr(i[0], comp)

  res.name <- teammates_get_name_query.perform(comp.possessedByPlr, @(_eid, playerComp) playerComp.name)
  teammatesUpdateEid(eid, res)
}

localPlayerTeam.subscribe_with_nasty_disregard_of_frp_update(@(_) teammatesQuery.perform(updateTeammatesStatus))
localPlayerTeamIsIncognito.subscribe_with_nasty_disregard_of_frp_update(@(_) teammatesQuery.perform(updateTeammatesStatus))

ecs.register_es("teammates_status_ui_es",
  {
    [["onInit", "onChange"]] = updateTeammatesStatus
    onDestroy = @(eid, _comp) teammatesDestroyEid(eid)
  },
  {
    comps_track = teammatesTrackComps
  }
)



let groupmatesCompsTrack = [
  ["team", ecs.TYPE_INT],
  ["groupId", ecs.TYPE_INT64],
  ["is_local", ecs.TYPE_BOOL, false],
  ["disconnected", ecs.TYPE_BOOL],
  ["possessed", ecs.TYPE_EID],
  ["name", ecs.TYPE_STRING],
  ["scoring_player__firstSpawnTime", ecs.TYPE_FLOAT],
  ["scoring_player__isExtractedSuccess", ecs.TYPE_BOOL],
  ["player__isDead", ecs.TYPE_BOOL],
]

let groupmatesQuery = ecs.SqQuery("groupmates_status_ui_query", {
  comps_ro = groupmatesCompsTrack
  comps_rq = ["player"]
})

function updateGroupmatesStatus(eid, comp) {
  if (comp["is_local"]
      || comp["team"] != localPlayerTeam.get()
      || localPlayerTeamIsIncognito.get()
      || comp.groupId != localPlayerGroupId.get()){
    groupmatesDestroyEid(eid)
    return
  }
  let res = {}
  foreach (i in groupmatesCompsTrack){
    res[i[0]] <- defComp_ctr(i[0], comp)
  }
  groupmatesUpdateEid(eid, res)
}

localPlayerTeam.subscribe_with_nasty_disregard_of_frp_update(@(_) groupmatesQuery.perform(updateGroupmatesStatus))
localPlayerTeamIsIncognito.subscribe_with_nasty_disregard_of_frp_update(@(_) groupmatesQuery.perform(updateGroupmatesStatus))
localPlayerGroupId.subscribe_with_nasty_disregard_of_frp_update(@(_) groupmatesQuery.perform(updateGroupmatesStatus))

ecs.register_es("groupmates_status_ui_es",
  {
    [["onInit", "onChange"]] = updateGroupmatesStatus
    onDestroy = @(eid, _comp) groupmatesDestroyEid(eid)
  },
  {comps_track = groupmatesCompsTrack, comps_rq = ["player"]}
)


return {
  teammatesSet,
  teammatesGetWatched,
  groupmatesSet,
  groupmatesGetWatched,
}
