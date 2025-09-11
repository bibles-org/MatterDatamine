from "%dngscripts/globalState.nut" import nestWatched
from "%ui/geo.nut" import getClusterByCode
from "auth" import get_country_code
from "matching.api" import matching_listen_notify
from "%ui/matchingClient.nut" import matchingCall
from "eventbus" import eventbus_subscribe
from "%ui/ui_library.nut" import *
from "math" import min
from "%sqstd/string.nut" import utf8ToUpper

let connectHolder = require("%ui/connectHolderR.nut")
let { onlineSettingUpdated, settings } = require("%ui/options/onlineSettings.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

let logC = with_prefix("[CLUSTERS] ")

const CLUSTERS_KEY = "selectedClusters"

let availableClustersDef = ["EU", "RU", "US", "JP"]
let debugClusters = []

let clustersViewMap = { RU = "EEU" }
let clusterLoc = @(cluster) loc(clustersViewMap?[cluster] ?? cluster)
let countryLoc = @(country) loc($"country/{country}", utf8ToUpper(country))



let matchingClusters = nestWatched("matchingClusters", [])

const INITIAL_DELAY = 5
const MAX_DELAY = 180
local currentDelay = INITIAL_DELAY

function fetchClustersFromMatching() {
  if (isInBattleState.get())
    return
  if (!connectHolder.is_logged_in()) {
    currentDelay = INITIAL_DELAY
    return
  }
  let self = callee()
  matchingCall("hmanager.fetch_clusters_list",
    function (response) {
      if (response.error != 0) {
        currentDelay = min(currentDelay*2, MAX_DELAY) 
        gui_scene.resetTimeout(currentDelay, self)
      }
      else {
        logC("clusters from matching server", response.clusters)
        currentDelay = INITIAL_DELAY
        matchingClusters.set(response.clusters)
      }
    }
  )
}

matchingClusters.subscribe(function(v) {
  if (v.len() == 0) {
    gui_scene.resetTimeout(currentDelay, fetchClustersFromMatching)
  }
  logC("matchingClusters:", v)
})

eventbus_subscribe("matching.connectHolder.ready", @(...) fetchClustersFromMatching())
fetchClustersFromMatching()

matching_listen_notify("hmanager.notify_clusters_changed")
eventbus_subscribe("hmanager.notify_clusters_changed", function(...) { fetchClustersFromMatching() })

let availableClusters = Computed(function() {
  local available = matchingClusters.get().filter(@(v) v!="debug")
  if (available.len()==0)
    available = clone availableClustersDef
  return available.extend(debugClusters)
})

function validateClusters(clusters, available){
  log("validate clusters. clusters:", clusters, "available:", available)
  clusters = clusters.filter(@(has, cluster) has && available.indexof(cluster)!=null)
  local country_code = get_country_code().toupper()
  let localData = getClusterByCode({ code = country_code })
  logC("country code:", country_code, "localData:", localData)
  let cluster = localData.cluster
  log("tryselectCluster:", cluster, "localData:", localData, "available:", available)
  if (available.indexof(cluster) != null)
    clusters[cluster] <- true
  if (clusters.len()==0 && available.len()>0)
    clusters[available[0]] <- true
  log("result valid clusters:", clusters)
  return clusters
}

let clusters = nestWatched("clusters", validateClusters({}, availableClusters.get()))

onlineSettingUpdated.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (!v)
    return
  console_print("online selectedClusters:", settings.get()?[CLUSTERS_KEY])
  clusters.set(validateClusters(settings.get()?[CLUSTERS_KEY] ?? {}, availableClusters.get()))
})
availableClusters.subscribe_with_nasty_disregard_of_frp_update(function(available) {
  clusters.set(validateClusters(clusters.get(), available))
})

let oneOfSelectedClusters = Computed(function() {
  foreach(c, has in clusters.get())
    if (has)
      return c
  return matchingClusters.get()?[0] ?? availableClustersDef[0]
})

clusters.subscribe_with_nasty_disregard_of_frp_update(function(clustersVal) {
  let needSave = isEqual(settings.get()?[CLUSTERS_KEY], clustersVal)
  log("onlineSettingsUpdated:", onlineSettingUpdated.get(), "isEqual to current:", needSave, "toSave:", clustersVal)
  if (!onlineSettingUpdated.get() || needSave)
    return
  settings.mutate(@(s) s[CLUSTERS_KEY] <- clustersVal.filter(@(has) has))
})

return {
  availableClusters
  clusters
  oneOfSelectedClusters
  clusterLoc
  countryLoc
}
