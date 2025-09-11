from "dagor.debug" import debug
from "dasevents" import CmdSendUserDedicatedPermissions, sendNetEvent

import "%dngscripts/ecs.nut" as ecs
from "%sqGlob/library_logs.nut" import *

let userInfo = require("%sqGlob/userInfo.nut")

let playerSessionQueue = ecs.SqQuery("playerSessionQueue", { comps_rq = ["player_session"] })

function sendingPermissions(eid, comp) {
  playerSessionQueue.perform(function(_evt, _comps){
    if (!comp.is_local)
      return
    let dedicatedPermJwt = userInfo.get()?.dedicatedPermJwt
    if (dedicatedPermJwt==null)
      return
    debug($"Send dedicated permissions for user: {userInfo.get().userId}")
    sendNetEvent(eid, CmdSendUserDedicatedPermissions({jwt=dedicatedPermJwt}))
  })
}

ecs.register_es("raid_profile_sending_permissions_for_local_player", {
  [["onInit", "onChange"]] = sendingPermissions
}, {
  comps_rq = ["player"]
  comps_track = [["is_local", ecs.TYPE_BOOL]]
}, {
  tags = "gameClient"
})
