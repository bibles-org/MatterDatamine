from "clientlog" import send_error_log
from "statsd" import send_counter
from "eventbus" import eventbus_subscribe
from "dagor.http" import httpRequest, HTTP_SUCCESS
from "json" import parse_json
from "settings" import get_setting_by_blk_path
from "app" import get_circuit_conf

from "%sqstd/string.nut" import isStringInteger
from "%ui/ui_library.nut" import *
from "%sqGlob/appInfo.nut" import exe_version
from "%sqstd/version.nut" import mkVersionFromString, versionToInt
from "%dngscripts/globalState.nut" import nestWatched
from "%ui/state/clientState.nut" import language
from "%ui/options/onlineSettings.nut" import onlineSettingUpdated, settings
from "%ui/httpPkg.nut" import getPlatformId, getLanguageId
from "%ui/state/client_version.nut" import maxVersionInt
let { playerStats } = require("%ui/profile/profileState.nut")
let { isLoggedIn } = require("%ui/login/login_state.nut")

let changelogDisabled = get_setting_by_blk_path("disableChangelog") ?? false

let extNewsUrl = get_circuit_conf()?.newsUrl
  ?? get_setting_by_blk_path("newsUrl")
  ?? "https://activematter.game/news/#!/"

let changelogVersionsUrl = get_circuit_conf()?.versionUrl
  ?? get_setting_by_blk_path("versionUrl")
  ?? "https://newsfeed.gap.gaijin.net/api/patchnotes/active_matter_pc/{language}/?platform={platform}" 

let changelogPatchnoteUrl = get_circuit_conf()?.patchnoteUrl
  ?? get_setting_by_blk_path("patchnoteUrl")
  ?? "https://newsfeed.gap.gaijin.net/api/patchnotes/active_matter_pc/{language}/{id}?platform={platform}" 

function logError(event, params = {}) {
  log(event, params)
  send_error_log(event, {
    attach_game_log = true
    collection = "events"
    meta = {
      hint = "error"
      exe_version = exe_version.get()
      language = language.get()
    }.__update(params)
  })
}

const UseEventBus = true

const SAVE_ID = "ui/lastSeenVersionId"
const PatchnoteIds = "PatchnoteIds"

let lastSeenVersionIdState = Computed(function() {
  if (!onlineSettingUpdated.get())
    return -1
  let val = settings.get()?[SAVE_ID]
  return isStringInteger(val) ? val.tointeger() : 0
})

let chosenPatchnote = Watched(null)
let chosenPatchnoteLoaded = nestWatched("chosenPatchnoteLoaded", false)
let chosenPatchnoteContent = nestWatched("chosenPatchnoteContent", "")
let chosenPatchnoteTitle = nestWatched("chosenPatchnoteTitle", "")
let patchnotesReceived = nestWatched("patchnotesReceived", false)
let versions = nestWatched("versions", [])

const MAX_TAB_INDEX = 7

function mkVersion(v){
  local tVersion = v?.version ?? ""
  let versionl = tVersion.split(".").len()
  local versionType = v?.type
  if (versionl!=4) {
    log($"incorrect patchnote version {tVersion}")
    if (versionl==3) {
      tVersion = $"{tVersion}.0"
      if (versionType==null)
        versionType = "major"
    }
    else
      throw null
  }
  let version = mkVersionFromString(tVersion)
  local titleshort = v?.titleshort ?? "undefined"
  if (titleshort == "undefined" || titleshort.len() > 50 )
    titleshort = null
  return {
    version
    title = v?.title ?? tVersion
    tVersion
    versionType
    titleshort
    iVersion = versionToInt(version)
    id = v.id
    date = v?.date ?? ""
    alwaysShowPopup = v?.alwaysShowPopup ?? false
  }
}

function filterVersions(vers) {
  let res = []
  local foundMajor = false
  let maxVer = maxVersionInt.get()
  foreach (idx, version in vers) {
    if (idx >= MAX_TAB_INDEX && foundMajor)
      break
    else if ( maxVer> 0 && maxVer < version.iVersion) {
      continue
    }
    else if (version.versionType=="major"){
      res.append(version)
      foundMajor = true
    }
    else if (idx < MAX_TAB_INDEX && !foundMajor){
      res.append(version)
    }
  }
  return res
}

function processPatchnotesList(response) {
  let { status = -1, http_code = 0, body = null } = response
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code) {
    send_counter("changelog_receive_errors", 1, { http_code, stage = "get_versions" })
    return
  }
  local result
  try {
    result = parse_json(body?.as_string())?.result
  } catch(e) {
    log("error processPatchnotesList", e)
  }

  if (result == null) {
    logError("changelog_parse_errors", { stage = "get_versions" })
    send_counter("changelog_parse_errors", 1, { stage = "get_versions" })
    versions.set([])
    patchnotesReceived.set(false)
    return
  }

  log("changelog_success_versions", result)
  versions.set(filterVersions(result.map(mkVersion)))
  patchnotesReceived.set(true)
}

function requestPatchnotes(){
  let url = changelogVersionsUrl.subst({
      language = getLanguageId()
      platform = getPlatformId()
    })
  let request = { method = "GET" url }
  if (UseEventBus)
    request.respEventId <- PatchnoteIds
  else
    request.callback <- processPatchnotesList
  patchnotesReceived.set(false)
  httpRequest(request)
}



let isVersion = @(version) type(version?.version) == "array"
  && type(version?.iVersion) == "integer"
  && type(version?.tVersion) == "string"

function findBestVersionToshow(versionsList = versions, lastSeenVersionNum = 0) {
  
  lastSeenVersionNum = lastSeenVersionNum ?? 0
  versionsList = versionsList ?? []
  local res = null
  foreach (version in versionsList) {
    if (version.alwaysShowPopup && res == null)
      return version
    if (lastSeenVersionNum < version.id) {
      if (version.versionType == "major")
        return version
      res = version
    }
    else
      break
  }
  return res
}

let unseenPatchnote = Computed(@() !onlineSettingUpdated.get() ? null
  : findBestVersionToshow(versions.get(), lastSeenVersionIdState.get()))

let curPatchnote = Computed(@()
  chosenPatchnote.get() ?? unseenPatchnote.get() ?? versions.get()?[0])

function markSeenVersion(v) {
  if (v == null)
    return
  if (v.id > lastSeenVersionIdState.get())
    settings.mutate(@(value) value[SAVE_ID] <- v.id)
}

function markLastSeen() {
  let v = versions.get()?[0]
  markSeenVersion(v)
}

let updateVersion = @() markSeenVersion(curPatchnote.get())

const PatchnoteReceived = "PatchnoteReceived"

let patchnotesCache = persist("patchnotesCache", @() {})

function setPatchnoteResult(result){
  chosenPatchnoteContent.set(result?.content ?? [])
  chosenPatchnoteTitle.set(result?.title ?? "")
  log("show patchnote:",result?.content)
  chosenPatchnoteLoaded.set(true)
  updateVersion()
}

function cachePatchnote(response) {
  let { status = -1, http_code = 0, body = null } = response
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code) {
    send_counter("changelog_receive_errors", 1, { http_code, stage = "get_patchnote" })
  }

  local result
  try {
    result = parse_json(body?.as_string())?.result
  } catch(e) {
    log("error reading patchnotes", e)
  }

  if (result == null) {
    logError("changelog_parse_errors", { stage = "get_patchnote" })
    send_counter("changelog_parse_errors", 1, { stage = "get_patchnote" })
    return
  }

  log("changelog_success_patchnote")
  setPatchnoteResult(result)
  if (result?.id)
    patchnotesCache[result.id] <- result
}

function requestPatchnote(v){
  if (v.id in patchnotesCache) {
    return setPatchnoteResult(patchnotesCache[v.id])
  }
  let url = changelogPatchnoteUrl.subst({
      language = getLanguageId()
      platform = getPlatformId()
      id = v.id
    })
  let request = { method = "GET" url }
  if (UseEventBus)
    request.respEventId <- PatchnoteReceived
  else
    request.callback <- cachePatchnote
  chosenPatchnoteLoaded.set(false)
  httpRequest(request)
}

if (UseEventBus) {
  eventbus_subscribe(PatchnoteIds, processPatchnotesList)
  eventbus_subscribe(PatchnoteReceived, cachePatchnote)
}

let curPatchnoteIdx = Computed( @() versions.get().indexof(curPatchnote.get()) ?? 0)

function haveUnseenMajorVersions(){
  let bestUnseenVersion = findBestVersionToshow(versions.get(), lastSeenVersionIdState.get())
  return (bestUnseenVersion != null && bestUnseenVersion.versionType == "major")
}

function haveUnseenHotfixVersions(){
  let bestUnseenVersion = findBestVersionToshow(versions.get(), lastSeenVersionIdState.get())
  return (bestUnseenVersion != null && bestUnseenVersion.versionType != "major")
}

let haveUnseenVersions = Computed(@() unseenPatchnote.get() != null)

function selectPatchnote(v) {
  chosenPatchnote.set(v)
  requestPatchnote(v)
}

let mkChangePatchNote = @(delta=1) function() {
  if (versions.get().len() == 0)
    return
  let nextIdx = clamp(curPatchnoteIdx.get()-delta, 0, versions.get().len()-1)
  let patchnote = versions.get()[nextIdx]
  selectPatchnote(patchnote)
}

let nextPatchNote = mkChangePatchNote()
let prevPatchNote = mkChangePatchNote(-1)

let patchnotesReady = Computed(@() isLoggedIn.get() && patchnotesReceived.get())

patchnotesReady.subscribe_with_nasty_disregard_of_frp_update(function(v){
  let stats = playerStats.get()?.stats["operative"]
  let totalStats = (stats?["raid_count"] ?? 0) + (stats?["nexus_count"] ?? 0)
  if (totalStats < 1) { 
    markLastSeen()
    return
  }
  if (!v || !haveUnseenVersions.get() || curPatchnote.get() == null)
    return

  selectPatchnote(curPatchnote.get())
})

console_register_command(function() {
  if (SAVE_ID in settings.get())
    settings.mutate(@(v) v.$rawdelete(SAVE_ID))
}, "changelog.reset")

console_register_command(requestPatchnotes, "changelog.requestVersions")

return {
  extNewsUrl
  changelogDisabled
  curPatchnote
  versions
  patchnotesReceived
  patchnotesReady
  isVersion
  findBestVersionToshow
  haveUnseenHotfixVersions
  haveUnseenVersions
  haveUnseenMajorVersions
  curPatchnoteIdx
  nextPatchNote
  prevPatchNote
  updateVersion
  requestPatchnote
  chosenPatchnote
  chosenPatchnoteContent
  chosenPatchnoteTitle
  chosenPatchnoteLoaded
  requestPatchnotes
  maxVersionInt
  markLastSeen
  selectPatchnote
}