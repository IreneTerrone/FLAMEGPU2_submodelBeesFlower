#ifndef AGENT_FUNCTIONS_CUH_
#define AGENT_FUNCTIONS_CUH_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;

/**
 * Priority is based solely on how long the movingAgent has been waiting to move
 * plus a small random factor to break ties.
 */
FLAMEGPU_AGENT_FUNCTION(calculate_priority, MessageNone, MessageNone) {
    int wait = FLAMEGPU->getVariable<int>("wait");
    
    // Priority = wait time + random tie breaker [0, 1)
    float priority = (float)wait + FLAMEGPU->random.uniform<float>();
    FLAMEGPU->setVariable<float>("priority", priority);
    
    return ALIVE;
}

/**
 * If the movingAgent moved, reset its wait counter. Otherwise, increment it.
 */
FLAMEGPU_AGENT_FUNCTION(update_wait_status, MessageNone, MessageNone) {
    int moved = FLAMEGPU->getVariable<int>("moved_this_step");
    int wait = FLAMEGPU->getVariable<int>("wait");
    
    if (moved == 1) {
        wait = 0;
    } else {
        wait += 1;
    }
    
    FLAMEGPU->setVariable<int>("wait", wait);
    return ALIVE;
}

#endif
