from "%ui/ui_library.nut" import *

let trashBinItems = Watched([])

function isItemInTrashBin(item) {
  let tb = trashBinItems.get()
  return tb.findindex(@(stackedItems) stackedItems.eids.findindex(@(v) item.eids.contains(v)) != null)
}

return {
  trashBinItems
  isItemInTrashBin
}