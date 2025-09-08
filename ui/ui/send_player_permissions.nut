import "%dngscripts/ecs.nut" as ecs
from "%sqGlob/library_logs.nut" import *

let userInfo = require("%sqGlob/userInfo.nut")
let { debug } = require("dagor.debug")
let { CmdSendUserDedicatedPermissions, sendNetEvent } = require("dasevents")

let playerSessionQueue = ecs.SqQuery("playerSessionQueue", { comps_rq = ["player_session"] })

function sendingPermissions(eid, comp) {
  playerSessionQueue.perform(function(_evt, _comps){
    if (!comp.is_local)
      return
    let dedicatedPermJwt = userInfo.value?.dedicatedPermJwt
    if (dedicatedPermJwt==null)
      return
    debug($"Send dedicated permissions for user: {userInfo.value.userId}")
    sendNetEvent(eid, CmdSendUserDedicatedPermissions({jwt=dedicatedPermJwt}))
  })
}

ecs.register_es("raid_profile_sending_permissions_for_local_player", {
  [["onInit", "onChange"]] = sendingPermissions
}, {
  comps_rq = ["player"]
  comps_track = [["is_local", ecs.TYPE_BOOL]]
}, {
  tags = "gameClient", after="client_start_player_preparing"
})
