import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {pushPlayerEvent} = require("eventlog.nut")
let {secondsToStringLoc} = require("%ui/helpers/time.nut")
let {CmdHeroLogExEvent, CmdHeroLogExEventLocal} = require("dasevents")
let {sound_play} = require("%dngscripts/sound_system.nut")

ecs.register_es("cmd_hero_log_ex_event_es",
  { [[CmdHeroLogExEvent, CmdHeroLogExEventLocal]] = function onCmdHeroLogExEvent(evt, _eid, _comp) {
      local eventData = clone(evt.data.getAll())
      if (evt.event == "interaction_denied")
        sound_play("ui_sounds/access_denied")
      evt.data.getAll().each(function(slot, key) {
        if (key.startswith("_requiresTime/"))
          eventData[key] <- secondsToStringLoc(slot)
        else if (typeof(slot)=="string")
          eventData[key] <- loc(slot, eventData)
      })
      let e = {event=evt.event, text=loc(evt.key, eventData), myTeamScores=false}
      pushPlayerEvent(e)
    }
  },
  { comps_rq = ["hero"] }, {tags="gameClient"}
)
