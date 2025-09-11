from "%ui/ui_library.nut" import *

let { settings, onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")

let FAVORITE_ITEMS_ONLINE_SETTINGS = "favoriteMarketItems"

let favoriteItems = mkWatched(persist, "favoriteItems", [])

favoriteItems.subscribe_with_nasty_disregard_of_frp_update(function(items){
  if (!onlineSettingUpdated.get())
    return
  settings.mutate(@(v) v[FAVORITE_ITEMS_ONLINE_SETTINGS] <- items)
})

onlineSettingUpdated.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (!v)
    return
  favoriteItems.set(settings.get()?[FAVORITE_ITEMS_ONLINE_SETTINGS] ?? [])
})

return {
  favoriteItems
}