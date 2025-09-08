#default:forbid-root-table

import "%dngscripts/ecs.nut" as ecs
require("%sqGlob/sqevents.nut")

ecs.clear_vm_entity_systems()

print("AM scripts init started:\n")
require("%scripts/game/report_logerr.nut")
print("AM scripts init finished\n")
