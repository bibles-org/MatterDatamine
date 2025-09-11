from "settings" import get_setting_by_blk_path
from "dagor.fs" import scan_folder

from "%ui/ui_library.nut" import *

let autofiles = scan_folder({root="ui", files_suffix=".avif", recursive=false}).filter(@(v) v.startswith("ui/login_am_bg_"))

let appBgImages = autofiles.len() >0 ? autofiles : (get_setting_by_blk_path("bgImage") ?? "")
  .split(";")
  .map(@(v) v.strip())
  .filter(@(v) v!="")

return {
  appBgImages
}
