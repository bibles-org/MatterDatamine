from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { updateRefreshTimer } = require("%ui/leaderboard/lb_state_base.nut")

let isOnPlayerBase = mkWatched(persist, "isOnPlayerBase", false)
ecs.register_es("track_game_type_player_base", {
  onInit = function(_evt,_comps) {
    isOnPlayerBase.set(true)
    updateRefreshTimer(true)
  }
  onDestroy = function(_evt,_comps) {
    isOnPlayerBase.set(false)
    updateRefreshTimer(false)
  }
},{
  comps_ro = [["player_base", ecs.TYPE_TAG]]
})

let isInPlayerSession = mkWatched(persist, "isInPlayerSession", false)
ecs.register_es("track_game_type_raid", {
  onInit = @(_evt,_comps) isInPlayerSession.set(true)
  onDestroy = @(_evt,_comps) isInPlayerSession.set(false)
},{
  comps_ro = [["player_session", ecs.TYPE_TAG]]
})

return{
  isInPlayerSession
  isOnPlayerBase
}
