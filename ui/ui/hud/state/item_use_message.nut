import "%ui/components/msgbox.nut" as msgbox

from "dasevents" import TryUseItem

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let itemMessageQuery = ecs.SqQuery("itemMessageQuery", {comps_ro = [["item__useMessage", ecs.TYPE_STRING]]})

ecs.register_es("display_item_message_es", {
    [TryUseItem] = function(_evt, eid, _comp){
      itemMessageQuery.perform(eid, function(_item_eid, comp){
        msgbox.showMsgbox({
          text = loc(comp.item__useMessage)
          buttons = [
            { text=loc("Ok"), action = @() null }
          ]
        })
      })
    }
  },
  {
    comps_rq = ["hero"]
  }
)
