import "%ui/notifications/matchingNotifications.nut" as matchingNotifications
from "%ui/profile/server_game_profile.nut" import loadFullProfile

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


let is_player_base_query = ecs.SqQuery("is_player_base_query", { comps_rq=[["player_base", ecs.TYPE_TAG]] })

matchingNotifications.subscribe("profile", function(ev){
  if (!(is_player_base_query.perform(@(...) true) ?? false))
    return
  if (ev.func == "newmail")
    return
  log($"[Matching notification] From <{ev.from}> message <{ev.func}>.")
  loadFullProfile()
})
