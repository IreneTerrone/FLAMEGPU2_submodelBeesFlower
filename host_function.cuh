#ifndef HOST_FUNCTION_CUH_
#define HOST_FUNCTION_CUH_

#include "flamegpu/flamegpu.h"
#include <vector>
#include <algorithm>
#include <numeric>
#include <random>

using namespace flamegpu;

/**
 * Initialize only the 'movingAgent' agents.
 */
FLAMEGPU_INIT_FUNCTION(createAgent) {
    const int GRID_DIM = 100;
    const int NUM_AGENTS = 2000;
    auto agent_api = FLAMEGPU->agent("movingAgent", "active");
    
    // Create list of all possible indices to ensure unique initial positions
    std::vector<int> available_indices(GRID_DIM * GRID_DIM);
    std::iota(available_indices.begin(), available_indices.end(), 0);
    
    std::mt19937 g(std::random_device{}());
    std::shuffle(available_indices.begin(), available_indices.end(), g);

    for (int i = 0; i < NUM_AGENTS; ++i) {
        int index = available_indices[i];
        int x = index / GRID_DIM;
        int y = index % GRID_DIM;
        
        auto agent = agent_api.newAgent();
        agent.setVariable<int>("x", x);
        agent.setVariable<int>("y", y);
        agent.setVariable<int>("wait", 0);
        agent.setVariable<float>("priority", 0.0f);
        agent.setVariable<int>("target_x", -1);
        agent.setVariable<int>("target_y", -1);
        agent.setVariable<int>("moved_this_step", 0);
    }
}

#endif
