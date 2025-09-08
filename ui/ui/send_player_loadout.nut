

import "%dngscripts/ecs.nut" as ecs
from "%sqGlob/library_logs.nut" import *

let {
  playerProfileLoadout,
  teamColorIdxs
} = require("%ui/profile/profileState.nut")
let { CmdSendPlayerProfile, sendNetEvent, EventPlayerFinishedOfflineRaid } = require("dasevents")
let { dgs_get_settings } = require("dagor.system")
let { loadJson, read_text_directly_from_fs_file, object_to_json_string, parse_json } = require("%sqstd/json.nut")
let defaultRaidProfile = require("%ui/profile/default_game_profile.nut")
let { get_setting_by_blk_path } = require("settings")
let { curQueueParam } = require("%ui/quickMatchQueue.nut")
let { requestProfileServer } = require("%sqGlob/profile_server.nut")

let profileFilename = get_setting_by_blk_path("debug/AMJsonPath") ?? "active_matter.profile2.json"


function loadProfileFromFile() {
  let result = {signedToken = "", unsignedToken = {}}
  local debugToken = {}

  local loadedProfile = loadJson(profileFilename, {load_text_file = read_text_directly_from_fs_file})
  local defaultProfileClone = clone defaultRaidProfile
  defaultProfileClone.loadoutItems = defaultProfileClone.loadoutItems.map(function(item) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName)
    let charges = template?.getCompValNullable("item__countPerStack") ??
                  template?.getCompValNullable("item_holder__maxItemCount") ??
                  template?.getCompValNullable("gun__maxAmmo") ??
                  template?.getCompValNullable("item__amount")
    if (charges != null)
      item.charges <- charges
    return item
  })
  defaultProfileClone.mints = defaultProfileClone.mints.map(function(mint) {
    mint.items = mint.items.map(function(item) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName)
      let charges = template?.getCompValNullable("item__countPerStack") ??
                    template?.getCompValNullable("item_holder__maxItemCount") ??
                    template?.getCompValNullable("gun__maxAmmo") ??
                    template?.getCompValNullable("item__amount")
      if (charges != null)
        item.charges <- charges
      return item
    })
    return mint
  })
  local defaultProfile = parse_json(object_to_json_string(defaultProfileClone))

  result.signedToken = loadedProfile?.jwtToken ?? ""
  if (result.signedToken.len() == 0) {
    debugToken["sessionId"] <- loadedProfile?.sessionId ?? 0
    debugToken["userId"] <- loadedProfile?.userId ?? 0
    debugToken["loadoutItems"] <- loadedProfile?.loadoutItems ?? defaultProfile?.loadoutItems ?? []
    debugToken["unlocks"] <- loadedProfile?.unlocks ?? defaultProfile?.unlocks ?? []
    debugToken["contracts"] <- loadedProfile?.contracts ?? defaultProfile?.contracts ?? []
    debugToken["rentedEquipmentSeed"] <- loadedProfile?.rentedEquipmentSeed ?? defaultProfile?.rentedEquipmentSeed ?? ""
    debugToken["raidName"] <- loadedProfile?.raidName ?? defaultProfile?.raidName ?? ""
    debugToken["dailyStatsReward"] <- loadedProfile?.dailyStatsReward ?? defaultProfile?.dailyStatsReward ?? []
    debugToken["dailyStatsRewardInfo"] <- loadedProfile?.dailyStatsRewardInfo ?? defaultProfile?.dailyStatsRewardInfo ?? []
    debugToken["mints"] <- loadedProfile?.mints ?? defaultProfile?.mints ?? []
    debugToken["loadouts_agency"] <- loadedProfile?.loadouts_agency ?? defaultProfile?.loadouts_agency ?? []
    result.signedToken = object_to_json_string(debugToken)
  }

  result.unsignedToken["teamInfo"] <- loadedProfile?.teamInfo ?? {}

  return result
}

let playerSessionQueue = ecs.SqQuery("playerSessionQueue", { comps_rq = ["player_session"] })

function sendingProfile(eid, comp) {
  playerSessionQueue.perform(function(_evt, _comps){
    if (!comp.is_local)
      return

    local signedToken = playerProfileLoadout.value
    local unsignedToken = {}
    if (dgs_get_settings()?.debug?.useLocalFileInRaid ?? false) {
      
      
      let dataFromFile = loadProfileFromFile()
      signedToken = dataFromFile.signedToken
      unsignedToken = dataFromFile.unsignedToken
    }
    else {
      unsignedToken["teamInfo"] <- {
        team_color_idxs = [teamColorIdxs.value.primary, teamColorIdxs.value.secondary]
      }
      if (curQueueParam.get()?.queueRaid != null && (curQueueParam.get().queueRaid?.extraParams.isNewby ?? false)) {
        unsignedToken["raidInfo"] <- curQueueParam.get().queueRaid
      }
    }

    log("[Raid Profile] Local player created, sending profile state.")
    sendNetEvent(eid, CmdSendPlayerProfile({signedToken, unsignedToken = object_to_json_string(unsignedToken)}))
  })
}

ecs.register_es("raid_profile_sending_state_for_local_player",{
  [["onInit", "onChange"]] = sendingProfile
},
{
  comps_rq = ["player"]
  comps_track = [["is_local", ecs.TYPE_BOOL]]
},
{
  tags = "gameClient", after="client_start_player_preparing"
})

ecs.register_es("raid_profile_offline_send_result",{
  [[EventPlayerFinishedOfflineRaid]] = function(evt, _eid, comp) {
    if (!comp.is_local) {
      return
    }

    let data = parse_json(evt.data)
    requestProfileServer("apply_battle_result_offline", data, {}, @(_) null)
  }
},
{
  comps_rq = ["player"],
  comps_ro = [["is_local", ecs.TYPE_BOOL]]
},
{
  tags = "gameClient"
})
