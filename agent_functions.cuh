#ifndef AGENT_FUNCTIONS_CUH_
#define AGENT_FUNCTIONS_CUH_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;


FLAMEGPU_AGENT_FUNCTION(calculate_priority, MessageNone, MessageNone) {
    int is_at_flower = FLAMEGPU->getVariable<int>("is_at_flower");
    
    // If at a flower, priority is zero (satisfied/feeding)
    if (is_at_flower == 1) {
        FLAMEGPU->setVariable<float>("priority", 0.0f);
        return ALIVE;
    }

    float hunger_level = FLAMEGPU->getVariable<float>("hunger_level");
    int wait = FLAMEGPU->getVariable<int>("wait");
    float wh = FLAMEGPU->environment.getProperty<float>("WH");
    float ww = FLAMEGPU->environment.getProperty<float>("WW");
    
    float priority = hunger_level * wh + (float)wait * ww + FLAMEGPU->random.uniform<float>();
    FLAMEGPU->setVariable<float>("priority", priority);
    
    return ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(update_hunger_wait, MessageNone, MessageNone) {
    float hunger_level = FLAMEGPU->getVariable<float>("hunger_level");
    int wait = FLAMEGPU->getVariable<int>("wait");
    int is_at_flower = FLAMEGPU->getVariable<int>("is_at_flower");
    
    if (is_at_flower == 1) {
        // Feed: decrease hunger_level
        hunger_level -= 50.0f;
        if (hunger_level <= 0.0f) {
            hunger_level = 0.0f;
            // Once full, the bee is ready to move again in the next step
            is_at_flower = 0;
        }
        wait = 0;
    } else {
        // Hunger increases over time
        hunger_level += 3.0f;
        wait += 1;
    }
    
    FLAMEGPU->setVariable<float>("hunger_level", hunger_level);
    FLAMEGPU->setVariable<int>("wait", wait);
    FLAMEGPU->setVariable<int>("is_at_flower", is_at_flower);
    
    return ALIVE;
}

#endif
