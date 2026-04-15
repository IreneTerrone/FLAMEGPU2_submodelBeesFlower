#ifndef HOST_FUNCTION_CUH_
#define HOST_FUNCTION_CUH_

#include "flamegpu/flamegpu.h"
#include <vector>
#include <algorithm>
#include <numeric>
#include <random>

using namespace flamegpu;

FLAMEGPU_INIT_FUNCTION(createAgent) {
    const int GRID_DIM = 100;
    const int FLOWER_SPACING = 5; // Increased density

    // Create a 100x100 grid of cells
    auto cell_api = FLAMEGPU->agent("cell");
    for (int i = 0; i < GRID_DIM; ++i) {
        for (int j = 0; j < GRID_DIM; ++j) {
            auto cell = cell_api.newAgent();
            cell.setVariable<int>("x", i);
            cell.setVariable<int>("y", j);
            cell.setVariable<int>("is_occupied", 0);
            
            // Add nectar with more density and a bit of noise
            float nectar = 0.0f;
            if (i % FLOWER_SPACING == FLAMEGPU->random.uniform<int>(0, FLOWER_SPACING-1) && 
                j % FLOWER_SPACING == FLAMEGPU->random.uniform<int>(0, FLOWER_SPACING-1)) {
                nectar = FLAMEGPU->random.uniform<float>(10.0f, 50.0f);
            }
            cell.setVariable<float>("nectar", nectar);
        }
    }

    // Create bees at random unoccupied positions
    const int NUM_BEES = 50;
    auto bee_api = FLAMEGPU->agent("bee");
    
    // Create a list of all available coordinates
    std::vector<int> available_indices(GRID_DIM * GRID_DIM);
    std::iota(available_indices.begin(), available_indices.end(), 0);
    
    // Shuffle the indices using a predictable but random sequence from FLAMEGPU
    for (int i = available_indices.size() - 1; i > 0; --i) {
        int j = FLAMEGPU->random.uniform<int>(0, i);
        std::swap(available_indices[i], available_indices[j]);
    }
    
    for (int i = 0; i < NUM_BEES; ++i) {
        int index = available_indices[i];
        int x = index / GRID_DIM;
        int y = index % GRID_DIM;
        
        auto bee = bee_api.newAgent();
        bee.setVariable<int>("x", x);
        bee.setVariable<int>("y", y);
        bee.setVariable<float>("hunger_level", FLAMEGPU->random.uniform<float>(0.0f, 100.0f));
        bee.setVariable<int>("wait", 0);
        bee.setVariable<float>("priority", 0.0f);
        bee.setVariable<id_t>("target_cell_id", ID_NOT_SET);
        bee.setVariable<int>("target_x", 0);
        bee.setVariable<int>("target_y", 0);
        bee.setVariable<id_t>("last_flower_id", ID_NOT_SET);
    }
}

#endif
