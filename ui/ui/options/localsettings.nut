from "settings" import get_setting_by_blk_path, set_setting_by_blk_path_and_save

from "%ui/ui_library.nut" import *

return function(settingsPath, write = true) {
  
  return function(defVal, saveId) {
    let key = $"{settingsPath}{saveId}"
    let watch = Watched(get_setting_by_blk_path(key) ?? defVal)
    if (write)
      watch.subscribe(@(val) set_setting_by_blk_path_and_save(key, val))
    return watch
  }
}
