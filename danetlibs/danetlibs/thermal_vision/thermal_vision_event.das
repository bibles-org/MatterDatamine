module thermal_vision_event shared
require ecs

[cpp_event(unicast)]
struct OnChangeThermalActivePreset{}

[cpp_event(unicast)]
struct OnActiveThermalActivePreset{}