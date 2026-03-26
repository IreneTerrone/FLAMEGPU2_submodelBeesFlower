#ifndef HOST_FUNCTION_CUH_
#define HOST_FUNCTION_CUH_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;

FLAMEGPU_INIT_FUNCTION(createAgent) {
    const int GRID_SIZE = 10;
    const int SPACING = 10;

    // Create a grid of flowers
    auto flower_api = FLAMEGPU->agent("flower");
    for (int i = 0; i < GRID_SIZE; ++i) {
        for (int j = 0; j < GRID_SIZE; ++j) {
            auto flower = flower_api.newAgent();
            flower.setVariable<id_t>("id", flower.getID());
            flower.setVariable<float>("x", (float)(i * SPACING + SPACING / 2));
            flower.setVariable<float>("y", (float)(j * SPACING + SPACING / 2));
            flower.setVariable<float>("nectar", FLAMEGPU->random.uniform<float>(0.0f, 50.0f));
        }
    }

    // Create some initial bees
    const int NUM_BEES = 50;
    auto bee_api = FLAMEGPU->agent("bee");
    for (int i = 0; i < NUM_BEES; ++i) {
        auto bee = bee_api.newAgent();
        bee.setVariable<id_t>("id", bee.getID());
        bee.setVariable<float>("x", FLAMEGPU->random.uniform<float>(0.0f, 99.0f));
        bee.setVariable<float>("y", FLAMEGPU->random.uniform<float>(0.0f, 99.0f));
        bee.setVariable<float>("hunger_level", FLAMEGPU->random.uniform<float>(0.0f, 100.0f));
        bee.setVariable<int>("wait", 0);
        bee.setVariable<float>("priority", 0.0f);
        bee.setVariable<float>("target_x", 0.0f);
        bee.setVariable<float>("target_y", 0.0f);
        bee.setVariable<id_t>("target_flower_id", ID_NOT_SET);
        bee.setVariable<int>("at_flower", 0);
        bee.setVariable<id_t>("last_flower_id", ID_NOT_SET);
        bee.setVariable<int>("is_moving", 0);
    }
}

#endif
