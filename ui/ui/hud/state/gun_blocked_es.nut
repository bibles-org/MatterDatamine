from "%ui/hud/state/eventlog.nut" import pushPlayerEvent
from "dasevents" import EventOnGunBlocksShoot

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


ecs.register_es("gun_blocked_es", {
  [EventOnGunBlocksShoot] = function(evt, _eid, _comp){
    pushPlayerEvent({event="gun_blocked", text = loc(evt.reason), myTeamScores=false})
  },
}, { comps_rq = ["hero"] }, {tags="gameClient"})
