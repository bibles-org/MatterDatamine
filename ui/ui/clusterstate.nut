from "%ui/ui_library.nut" import *

let { getClusterByCode } = require("geo.nut")
let { get_country_code } = require("auth")
let { matching_listen_notify } = require("matching.api")
let { matchingCall } = require("%ui/matchingClient.nut")
let connectHolder = require("%ui/connectHolderR.nut")
let { onlineSettingUpdated, settings } = require("%ui/options/onlineSettings.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { eventbus_subscribe } = require("eventbus")

let logC = with_prefix("[CLUSTERS] ")

const CLUSTERS_KEY = "selectedClusters"

let availableClustersDef = ["EU", "RU", "US", "JP"]
let debugClusters = []

let clustersViewMap = { RU = "EEU" }
let clusterLoc = @(cluster) loc(clustersViewMap?[cluster] ?? cluster)
let countryLoc = @(country) loc($"country/{country}", country.toupper())


let matchingClusters = nestWatched("matchingClusters", [])
function fetchClustersFromMatching() {
  let self = callee()
  if (!connectHolder.is_logged_in()) {
    return
  }

  matchingCall("hmanager.fetch_clusters_list",
    function (response) {
      if (response.error != 0) {
        gui_scene.resetTimeout(5, self) 
      }
      else {
        logC("clusters from matching server", response.clusters)
        matchingClusters(response.clusters)
      }
    }
  )
}

matchingClusters.subscribe(function(v) {
  if (v.len() == 0)
    gui_scene.resetTimeout(5, fetchClustersFromMatching)
  logC("matchingClusters:", v)
})

eventbus_subscribe("matching.connectHolder.ready", @(...) fetchClustersFromMatching())
fetchClustersFromMatching()

matching_listen_notify("hmanager.notify_clusters_changed")
eventbus_subscribe("hmanager.notify_clusters_changed", function(...) { fetchClustersFromMatching() })

let availableClusters = Computed(function() {
  local available = matchingClusters.value.filter(@(v) v!="debug")
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

let clusters = nestWatched("clusters", validateClusters({}, availableClusters.value))

onlineSettingUpdated.subscribe(function(v) {
  if (!v)
    return
  console_print("online selectedClusters:", settings.value?[CLUSTERS_KEY])
  clusters(validateClusters(settings.value?[CLUSTERS_KEY] ?? {}, availableClusters.value))
})
availableClusters.subscribe(function(available) {
  clusters(validateClusters(clusters.value, available))
})

let oneOfSelectedClusters = Computed(function() {
  foreach(c, has in clusters.value)
    if (has)
      return c
  return matchingClusters.value?[0] ?? availableClustersDef[0]
})

clusters.subscribe(function(clustersVal) {
  let needSave = isEqual(settings.value?[CLUSTERS_KEY], clustersVal)
  log("onlineSettingsUpdated:", onlineSettingUpdated.value, "isEqual to current:", needSave, "toSave:", clustersVal)
  if (!onlineSettingUpdated.value || needSave)
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
