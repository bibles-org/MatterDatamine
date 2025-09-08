module activity_helper_checks_common shared

require ecs
require ecs.common
require ecs.soa_template


[soa_template]
struct ActivityHelperChecksData
  activity_helper_checks__eid : EntityId
  activity_helper_checks__startSearchActivityAt : float
  activity_helper_checks__lastCheckPosition : float3
  activity_helper_checks__currentPoint : float3
