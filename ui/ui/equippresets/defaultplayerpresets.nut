from "%ui/ui_library.nut" import *









let playerPreset_0 = {
  presetName = "Vepr"
  chronogene_primary_1 = {
    equipment_mod_body_0 = {
      itemTemplate = "armorplate_big_a"
      slotTemplateName = "armorplate_big_slot"
    }
    equipment_mod_right_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
    equipment_mod_pocket_0 = {
      itemTemplate = "item_healkit"
      slotTemplateName = "pocket_slot"
    }
    itemTemplate = "suit_militant_female_enforcer_item"
    equipment_mod_left_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
  }
  weapons = [
    {
      attachments = {
        magazine = {
          itemTemplate = "vepr_10rd_magazine"
        }
      }
      itemTemplate = "akm_47_civil_gun"
    }{} {}
    {
      attachments = {}
      itemTemplate = "knife_weapon"
    }
  ]
  flashlight = {
    attachments = {}
    itemTemplate = "flashlight_device"
  }
  pouch = {
    attachments = {}
    itemTemplate = "small_pouch"
  }
  backpack = {
    attachments = {}
    itemTemplate = "small_backpack"
  }
  helmet = {
    attachments = {}
    itemTemplate = "helmet_pasgt_tactical"
  }
  inventories = {
    safepack = {
      capacity = 0
      items = []
    }
    myItems = {
      capacity = 250
      items = [
        {
          count = 1
          ammoCount = 60
          ammoId = null
          countPerStack = 30
          itemTemplate = "box_7_62x39_magazine"
          isBoxedItem = true
        }
        {
          count = 2
          ammoCount = 10
          ammoId = null
          countPerStack = 0
          itemTemplate = "vepr_10rd_magazine"
          isBoxedItem = false
        }
      ]
    }
    backpack = {
      capacity = 400
      items = []
    }
  }
}


let playerPreset_1 = {
  presetName = "MP5"
  chronogene_primary_1 = {
    equipment_mod_body_0 = {
      itemTemplate = "armorplate_big_a"
      slotTemplateName = "armorplate_big_slot"
    }
    equipment_mod_right_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
    equipment_mod_pocket_0 = {
      itemTemplate = "item_healkit"
      slotTemplateName = "pocket_slot"
    }
    itemTemplate = "suit_militant_female_enforcer_item"
    equipment_mod_left_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
  }
  weapons = [
    {
      attachments = {
        magazine = {
          itemTemplate = "hk_mp5n_magazine"
        }
      }
      itemTemplate = "hk_mp5n_gun"
    }{} {}
    {
      attachments = {}
      itemTemplate = "knife_weapon"
    }
  ]
  flashlight = {
    attachments = {}
    itemTemplate = "flashlight_device"
  }
  pouch = {
    attachments = {}
    itemTemplate = "small_pouch"
  }
  backpack = {
    attachments = {}
    itemTemplate = "small_backpack"
  }
  helmet = {
    attachments = {}
    itemTemplate = "helmet_pasgt_tactical"
  }
  inventories = {
    safepack = {
      capacity = 0
      items = []
    }
    myItems = {
      capacity = 250
      items = [
        {
          count = 3
          ammoCount = 30
          ammoId = null
          countPerStack = 0
          itemTemplate = "hk_mp5n_magazine"
          isBoxedItem = false
        }
        {
          count = 1
          ammoCount = 96
          ammoId = null
          countPerStack = 32
          itemTemplate = "box_9x19_magazine"
          isBoxedItem = true
        }
      ]
    }
    backpack = {
      capacity = 400
      items = []
    }
  }
}

let playerPreset_2 = {
  presetName = "MB590"
  chronogene_primary_1 = {
    equipment_mod_body_0 = {
      itemTemplate = "armorplate_big_a"
      slotTemplateName = "armorplate_big_slot"
    }
    equipment_mod_right_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
    equipment_mod_pocket_0 = {
      itemTemplate = "item_healkit"
      slotTemplateName = "pocket_slot"
    }
    itemTemplate = "suit_militant_female_enforcer_item"
    equipment_mod_left_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
  }
  weapons = [
    {
      attachments = {}
      itemTemplate = "mossberg_590_gun"
    }{}
    {
      attachments = {
        magazine = {
          itemTemplate = "beretta_m9_magazine"
        }
      }
      itemTemplate = "beretta_m9_gun"
    }{}]
  flashlight = {
    attachments = {}
    itemTemplate = "flashlight_device"
  }
  pouch = {
    attachments = {}
    itemTemplate = "small_pouch"
  }
  backpack = {
    attachments = {}
    itemTemplate = "small_backpack"
  }
  helmet = {
    attachments = {}
    itemTemplate = "helmet_pasgt_tactical"
  }
  inventories = {
    safepack = {
      capacity = 0
      items = []
    }
    myItems = {
      capacity = 250
      items = [
        {
          count = 2
          ammoCount = 15
          ammoId = null
          countPerStack = 0
          itemTemplate = "beretta_m9_magazine"
          isBoxedItem = false
        }
        {
          count = 1
          ammoCount = 18
          ammoId = null
          countPerStack = 32
          itemTemplate = "box_9x19_magazine"
          isBoxedItem = true
        }
        {
          count = 1
          ammoCount = 48
          ammoId = null
          countPerStack = 12
          itemTemplate = "box_12_gauge_magazine"
          isBoxedItem = true
        }
      ]
    }
    backpack = {
      capacity = 400
      items = [
        {
          count = 1
          ammoCount = 12
          ammoId = null
          countPerStack = 12
          itemTemplate = "box_12_gauge_magazine"
          isBoxedItem = true
        }
      ]
    }
  }
}


let playerPreset_3 = {
  presetName = "Pistol"
  chronogene_primary_1 = {
    equipment_mod_body_0 = {
      itemTemplate = "armorplate_big_a"
      slotTemplateName = "armorplate_big_slot"
    }
    equipment_mod_right_leg_0 = {
      itemTemplate = null
      slotTemplateName = "armorplate_small_slot"
    }
    equipment_mod_pocket_0 = {
      itemTemplate = "item_healkit"
      slotTemplateName = "pocket_slot"
    }
    itemTemplate = "suit_militant_female_enforcer_item"
    equipment_mod_left_leg_0 = {
      itemTemplate = null
      slotTemplateName = "armorplate_small_slot"
    }
  }
  weapons = [{} {}
    {
      attachments = {
        magazine = {
          itemTemplate = "beretta_m9_magazine"
        }
      }
      itemTemplate = "beretta_m9_gun"
    }
    {
      attachments = {}
      itemTemplate = "knife_weapon"
    }
  ]
  flashlight = {
    attachments = {}
    itemTemplate = "flashlight_device"
  }
  pouch = {
    attachments = {}
    itemTemplate = "small_pouch"
  }
  backpack = {
    attachments = {}
    itemTemplate = "small_backpack"
  }
  helmet = {
    attachments = {}
    itemTemplate = "helmet_pasgt_tactical"
  }
  inventories = {
    safepack = {
      capacity = 0
      items = []
    }
    myItems = {
      capacity = 250
      items = [
        {
          count = 2
          ammoCount = 15
          ammoId = null
          countPerStack = 0
          itemTemplate = "beretta_m9_magazine"
          isBoxedItem = false
        }
        {
          count = 1
          ammoCount = 50
          ammoId = null
          countPerStack = 32
          itemTemplate = "box_9x19_magazine"
          isBoxedItem = true
        }
      ]
    }
    backpack = {
      capacity = 400
      items = []
    }
  }
}


let playerPreset_4 = {
  presetName = "Crossbow"
  chronogene_primary_1 = {
    equipment_mod_body_0 = {
      itemTemplate = "armorplate_big_a"
      slotTemplateName = "armorplate_big_slot"
    }
    equipment_mod_right_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
    equipment_mod_pocket_0 = {
      itemTemplate = "item_healkit"
      slotTemplateName = "pocket_slot"
    }
    itemTemplate = "suit_militant_female_enforcer_item"
    equipment_mod_left_leg_0 = {
      itemTemplate = "armorplate_small_a"
      slotTemplateName = "armorplate_small_slot"
    }
    equipment_mod_pocket_1 = {
      itemTemplate = "item_healkit"
      slotTemplateName = "pocket_slot"
    }
  }
  weapons = [{
      attachments = {}
      itemTemplate = "crossbow_gun"
    }{}
    {
      attachments = {
        magazine = {
          itemTemplate = "beretta_m9_magazine"
        }
      }
      itemTemplate = "beretta_m9_gun"
    }
    {
      attachments = {}
      itemTemplate = "knife_weapon"
    }
  ]
  flashlight = {
    attachments = {}
    itemTemplate = "flashlight_device"
  }
  pouch = {
    attachments = {}
    itemTemplate = "small_pouch"
  }
  backpack = {
    attachments = {}
    itemTemplate = "small_backpack"
  }
  helmet = {
    attachments = {}
    itemTemplate = "helmet_pasgt_tactical"
  }
  inventories = {
    safepack = {
      capacity = 0
      items = []
    }
    myItems = {
      capacity = 250
      items = [
        {
          count = 2
          ammoCount = 15
          ammoId = null
          countPerStack = 0
          itemTemplate = "beretta_m9_magazine"
          isBoxedItem = false
        }
        {
          count = 1
          ammoCount = 5
          ammoId = null
          countPerStack = 1
          itemTemplate = "crossbow_bolt_item"
          isBoxedItem = true
        }
        {
          count = 1
          ammoCount = 50
          ammoId = null
          countPerStack = 32
          itemTemplate = "box_9x19_magazine"
          isBoxedItem = true
        }
      ]
    }
    backpack = {
      capacity = 400
      items = [
        {
          count = 1
          ammoCount = 15
          ammoId = null
          countPerStack = 1
          itemTemplate = "crossbow_bolt_item"
          isBoxedItem = true
        }
      ]
    }
  }
}



return {
  playerPreset_0
  playerPreset_1
  playerPreset_2
  playerPreset_3
  playerPreset_4
}