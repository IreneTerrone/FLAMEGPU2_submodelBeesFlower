#ifndef HOST_FUNCTION_CUH_
#define HOST_FUNCTION_CUH_

#include "flamegpu/flamegpu.h"
#include <vector>
#include <algorithm>
#include <numeric>
#include <random>
#include <map>

using namespace flamegpu;

FLAMEGPU_INIT_FUNCTION(createAgent) {
    const int GRID_DIM = 100;
    const int FLOWER_SPACING = 5;

    // Create bees at random unique positions first
    const int NUM_BEES = 2000;
    auto bee_api = FLAMEGPU->agent("bee");
    
    std::vector<int> available_indices(GRID_DIM * GRID_DIM);
    std::iota(available_indices.begin(), available_indices.end(), 0);
    
    std::mt19937 g(std::random_device{}());
    std::shuffle(available_indices.begin(), available_indices.end(), g);
    
    std::vector<bool> is_bee_at(GRID_DIM * GRID_DIM, false);

    for (int i = 0; i < NUM_BEES; ++i) {
        int index = available_indices[i];
        int x = index / GRID_DIM;
        int y = index % GRID_DIM;
        is_bee_at[index] = true;
        
        auto bee = bee_api.newAgent();
        bee.setVariable<int>("x", x);
        bee.setVariable<int>("y", y);
        bee.setVariable<float>("hunger_level", FLAMEGPU->random.uniform<float>(0.0f, 100.0f));
        bee.setVariable<int>("wait", 0);
        bee.setVariable<float>("priority", 0.0f);
        bee.setVariable<int>("target_x", -1);
        bee.setVariable<int>("target_y", -1);
        bee.setVariable<int>("last_flower_x", -1);
        bee.setVariable<int>("last_flower_y", -1);
        bee.setVariable<int>("is_at_flower", 0);
        bee.setVariable<int>("moved_this_step", 0);
    }

    // Create a 100x100 grid of cells and set occupancy
    auto cell_api = FLAMEGPU->agent("cell");
    for (int i = 0; i < GRID_DIM; ++i) {
        for (int j = 0; j < GRID_DIM; ++j) {
            int index = i * GRID_DIM + j;
            auto cell = cell_api.newAgent();
            cell.setVariable<int>("x", i);
            cell.setVariable<int>("y", j);
            cell.setVariable<int>("is_occupied", is_bee_at[index] ? 1 : 0);
            
            float nectar = 0.0f;
            if (i % FLOWER_SPACING == 0 && j % FLOWER_SPACING == 0) {
                nectar = FLAMEGPU->random.uniform<float>(10.0f, 50.0f);
            }
            cell.setVariable<float>("nectar", nectar);
        }
    }
}

#endif
