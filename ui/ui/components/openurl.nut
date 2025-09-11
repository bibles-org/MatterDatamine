from "auth" import get_authenticated_url_sso, YU2_OK
from "dagor.shell" import shell_execute
from "string" import startswith, strip
import "steam" as steam
import "regexp2" as regexp2
from "eventbus" import eventbus_subscribe_onehit
from "settings" import get_setting_by_blk_path
from "%ui/components/browserWidget.nut" import showBrowser
from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let logOU = require("%sqGlob/library_logs.nut").with_prefix("[OPEN_URL] ")
let openLinksInEmbeddedBrowser = get_setting_by_blk_path("openLinksInEmbeddedBrowser") ?? false

#allow-auto-freeze

enum AuthenticationMode {
  NOT_AUTHENTICATED = 0
  AUTHENTICATED = 1
  WEGAME_AUTH = 2
}

function open_url(url) {
  if (type(url)!="string" || (!startswith(url, "http://") && !startswith(url, "https://")))
    return false
  if (platform.is_sony)
    require("sony.www").open(url, "" , {})
  else if (platform.is_xbox)
    require("gdk.app").launch_browser(url)
  else if (platform.is_nswitch)
    require("nswitch.network").openUrl(url)
  else if (platform.is_pc) {
    if (openLinksInEmbeddedBrowser)
      showBrowser(url)
    else
      shell_execute({file=url})
  }
  else if (platform.is_android)
    shell_execute({file=url, cmd="action"})
  else
    log_for_user("Open url not implemented on this platform")
  return true
}

const URL_ANY_ENDING = @"(\/.*$|\/$|$)"
const AUTH_TOKEN_HOST = "https://login.gaijin.net/sso/getShortToken"

let addEnding = @(url) $"{url}{URL_ANY_ENDING}"

let urlTypes = [
  {
    typeName = "marketplace"
    autologin = true
    ssoService = "any"
    urlRegexpList = [
      regexp2(addEnding(@"^https?:\/\/trade\.gaijin\.net")),
      regexp2(addEnding(@"^https?:\/\/store\.gaijin\.net")),
      regexp2(addEnding(@"^https?:\/\/inventory-test-01\.gaijin\.lan")),
    ]
  },
  {
    typeName = "steam_market"
    autologin = false
    urlRegexpList = [
      regexp2(addEnding(@"^https?:\/\/store\.steampowered\.com"))
    ]
  },
  {
    typeName = "gaijin_support"
    autologin = true
    ssoService = "zendesk"
    urlRegexpList = [
      regexp2(addEnding(@"^https?:\/\/support\.gaijin\.net"))
    ]
  },
  {
    typeName = "bugreport"
    autologin = true
    ssoService = "any"
    urlRegexpList = [
      regexp2(addEnding(@"^https?:\/\/community\.gaijin\.net\/issues"))
    ]
  },
  {
    typeName = "gss"
    autologin = true
    ssoService = "any"
    urlRegexpList = [
      regexp2(addEnding(@"^https?:\/\/gss\.gaijin\.net"))
    ]
  },
  {
    typeName = "match any url"
    autologin = false
    urlRegexpList = null
  },
]

function getUrlTypeByUrl(url) {
  foreach(urlType in urlTypes) {
    if (!urlType.urlRegexpList)
      return urlType

    foreach(r in urlType.urlRegexpList)
      if (r.match(url))
        return urlType
  }

  return null
}


function openUrl(baseUrl, isAlreadyAuthenticated = false, shouldExternalBrowser = false, goToUrl = null) {
  let url = baseUrl ? strip(baseUrl) : ""
  if (url == "") {
    logOU("Error: tried to openUrl an empty url")
    return
  }

  let urlType = getUrlTypeByUrl(url)
  logOU($"Open type<{urlType.typeName}> url: {url}")
  logOU($"Base Url = {baseUrl}")

  if (goToUrl == null)
    goToUrl = (!shouldExternalBrowser && steam.is_overlay_enabled()) ? steam.open_url : open_url

  if (urlType.typeName == "steam_market" && !steam.is_overlay_enabled())
    logOU("Warning: trying to open steam url without steam overlay")

  if (isAlreadyAuthenticated || !urlType.autologin) {
    goToUrl(url)
    return
  }

  let cbEvent = $"openUrl.{url}"
  eventbus_subscribe_onehit(cbEvent,
    function(result)  {
      if (result.status == YU2_OK) {
        
        logOU($"Authentcated Url = {result.url}")
        goToUrl(result.url)
        return
      }
      logOU($"Error: failed to get_authenticated_url, status = {result.status}")
      goToUrl(baseUrl) 
    }
  )

  let { ssoService = null } = urlType
  if (ssoService == null || get_authenticated_url_sso == null) {
    logOU($"Error: failed to get_authenticated_url_sso, service is undefined")
    goToUrl(baseUrl) 
  }
  else
    get_authenticated_url_sso(baseUrl, AUTH_TOKEN_HOST, ssoService, cbEvent)
}

console_register_command(open_url, "app.open_url")

return {
  openUrl
  AuthenticationMode
}
