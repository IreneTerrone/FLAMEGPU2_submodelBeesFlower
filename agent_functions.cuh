#ifndef AGENT_FUNCTIONS_CUH_
#define AGENT_FUNCTIONS_CUH_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;


FLAMEGPU_AGENT_FUNCTION(calculate_priority, MessageNone, MessageNone) {
    float hunger_level = FLAMEGPU->getVariable<float>("hunger_level");
    int wait = FLAMEGPU->getVariable<int>("wait");
    float wh = FLAMEGPU->environment.getProperty<float>("WH");
    float ww = FLAMEGPU->environment.getProperty<float>("WW");
    
    // Hunger_level increases = higher priority
    // Priority = (Hunger level) * WH + Wait * WW
    float priority = hunger_level * wh + (float)wait * ww + FLAMEGPU->random.uniform<float>();
    FLAMEGPU->setVariable<float>("priority", priority);
    
    return ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(update_hunger_wait, MessageNone, MessageNone) {
    float hunger_level = FLAMEGPU->getVariable<float>("hunger_level");
    int wait = FLAMEGPU->getVariable<int>("wait");
    int at_flower = FLAMEGPU->getVariable<int>("at_flower");
    
    // Hunger increases over time
    hunger_level += 3.0f;
    
    // Wait increases every step they are not at a flower
    if(at_flower == 0) {
        wait += 1;
    } else {
        wait = 0; // Reset wait if we are at a flower
    }
    
    FLAMEGPU->setVariable<float>("hunger_level", hunger_level);
    FLAMEGPU->setVariable<int>("wait", wait);
    
    return ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(bee_receive_grant, MessageNone, MessageNone) {
    // If the bee is AT the flower (arrived in movement submodel)
    if (FLAMEGPU->getVariable<int>("at_flower") == 1) {
        // Final move into the flower exact coordinates
        FLAMEGPU->setVariable<float>("x", FLAMEGPU->getVariable<float>("target_x"));
        FLAMEGPU->setVariable<float>("y", FLAMEGPU->getVariable<float>("target_y"));
        
        // Feed: decrease hunger_level
        float hunger_level = FLAMEGPU->getVariable<float>("hunger_level");
        hunger_level -= 50.0f;
        if (hunger_level < 0.0f) hunger_level = 0.0f;
        
        FLAMEGPU->setVariable<float>("hunger_level", hunger_level);
        FLAMEGPU->setVariable<int>("wait", 0);
        FLAMEGPU->setVariable<id_t>("last_flower_id", FLAMEGPU->getVariable<id_t>("target_flower_id"));
        FLAMEGPU->setVariable<id_t>("target_flower_id", ID_NOT_SET);
        FLAMEGPU->setVariable<int>("at_flower", 0); // Done feeding, will search again next step
    }
    return ALIVE;
}

#endif
