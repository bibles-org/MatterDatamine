let platform = require("%sqstd/platform.nut")
let sony = require_optional("sony")
let { dgs_get_settings, DBGLEVEL } = require("dagor.system")
let { aliases, is_pc, is_gdk, SCE_REGION, platformId, consoleRevision } = platform


let winStoreAliases = ["xbox", "xboxOne", "xboxScarlett"]

let isPlatformRelevant = is_pc && is_gdk
  ? @(platforms)
      platforms.len() == 0 || platforms.findvalue(@(p) winStoreAliases.contains(p)) != null
  : @(platforms)
      platforms.len() == 0 || platforms.findvalue(@(p) aliases?[p] ?? (p == platformId)) != null

local ps4RegionName = "no region on this platform"

if (platform.is_sony && sony != null) {
   let SONY_REGION_NAMES = {
     [sony.region.SCEE]  = SCE_REGION.SCEE,
     [sony.region.SCEA]  = SCE_REGION.SCEA,
     [sony.region.SCEJ]  = SCE_REGION.SCEJ
   }
   ps4RegionName = SONY_REGION_NAMES[sony.getRegion()]
   aliases.__update({
     [$"{platformId}_{ps4RegionName}"] = true,
     [$"sony_{ps4RegionName}"] = true
   })
}



let isTouchPrimary = platform.is_mobile
  || (platform.is_pc && DBGLEVEL > 0 && dgs_get_settings()?.debug["touchScreen"])

return platform.__merge({
  aliases
  isPlatformRelevant
  ps4RegionName
  isTouchPrimary
  consoleRevision
})
