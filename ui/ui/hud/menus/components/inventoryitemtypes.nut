from "%ui/ui_library.nut" import *

return freeze({
  HERO_ITEM_CONTAINER = {name = "inventory", containerName="itemContainer", belongsToHero = true}
  DEBRIEFING_ITEM = {name = "debriefing", containerName="itemContainer", belongsToHero = true}
  STASH = {name = "stash", containerName="itemContainer", belongsToHero = false}
  REFINER_STASH = {name = "refinerStash", containerName="itemContainer", belongsToHero = false}
  REFINER_ON_PLAYER = {name = "refinerOnPlayer", containerName="itemContainer", belongsToHero = true}
  GROUND = {name = "ground", belongsToHero = false}
  EXTERNAL_ITEM_CONTAINER = {name = "external_inventory", containerName="itemContainer", belongsToHero = false}
  BACKPACK0 = {name = "backpack0", containerName="itemContainer", belongsToHero = true}
  SAFEPACK = {name = "safepack", containerName="itemContainer", belongsToHero = true}
  GENES_MAIN = { name = "mainGenes", containerName="mainGenes" }
  GENES_SECONDARY = { name = "secondaryGenes", containerName="secondaryGenes" }
  REFINER = { name = "refinerContainer", belongsToHero = false }
  WORKBENCH = { name = "wokrkbenchItemsList", belongsToHero = false }
  WORKBENCH_STASH = {name = "workbenchStash", containerName="itemContainer", belongsToHero = false}
  WORKBENCH_ITEMS_ON_PLAYER = {name = "workbenchItemsOnPlayer", containerName="itemContainer", belongsToHero = true}
  LOOTBOX_SHOW_RESULT = { name = "lootboxShowResult" }
  NEXUS_ALTER_STASH = { name = "nexusAlterStash" }
  REPLICATOR_ITEM = { name = "replicatorRecipe" }
})
