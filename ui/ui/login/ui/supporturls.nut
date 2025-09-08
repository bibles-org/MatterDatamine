let {get_setting_by_blk_path} = require("settings")
let {platformId} = require("%dngscripts/platform.nut")
let {circuit, version} = require("%sqGlob/appInfo.nut")

local bugReportUrl = get_setting_by_blk_path("communityBugTrackerURL")
if (bugReportUrl!=null)
  bugReportUrl = $"{bugReportUrl}?f.platform={platformId}&f.version={version.value}&f.circuit={circuit.value}"
else
  bugReportUrl=""

return {
  gaijinSupportUrl = get_setting_by_blk_path("gaijinSupportUrl") ?? "https://support.gaijin.net/"
  feedbackUrl      = get_setting_by_blk_path("feedbackUrl") ?? ""
  bugReportUrl
}

