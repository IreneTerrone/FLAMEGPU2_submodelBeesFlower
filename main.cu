#include <iostream>
#include <fstream>
#include "flamegpu/flamegpu.h"
#include "host_function.cuh"
#include "agent_functions.cuh"
#include "movement_submodel.cuh"

#define ENV_DIM 100
#define SIMULATION_STEPS 100

using namespace flamegpu;

// Global log file
std::ofstream bees_log;

FLAMEGPU_INIT_FUNCTION(initLog) {
    bees_log.open("bees_log.csv");
    bees_log << "step,id,x,y,hunger_level,wait,at_flower" << std::endl;
}

FLAMEGPU_STEP_FUNCTION(stepLogger) {
    auto bees = FLAMEGPU->agent("bee");
    auto& bee_pop = bees.getPopulationData();
    unsigned int step = FLAMEGPU->getStepCounter();
    
    // Validation: Check for collisions
    std::vector<int> occupancy(ENV_DIM * ENV_DIM, 0);
    int collisions = 0;

    for (const auto& bee : bee_pop) {
        int x = bee.getVariable<int>("x");
        int y = bee.getVariable<int>("y");

        int idx = x * ENV_DIM + y;
        occupancy[idx]++;
        if (occupancy[idx] > 1) {
            collisions++;
        }

        bees_log << step << ","
                 << bee.getID() << ","
                 << x << ","
                 << y << ","
                 << bee.getVariable<float>("hunger_level") << ","
                 << bee.getVariable<int>("wait") << ","
                 << bee.getVariable<int>("is_at_flower") << "\n";
    }

    if (collisions > 0) {
        std::cerr << "!!! STEP " << step << ": DETECTED " << collisions << " COLLISIONS !!!" << std::endl;
    }
    
    // Log cells with nectar once at the start
    if (step == 0) {
        std::ofstream flower_log("flowers_log.csv");
        flower_log << "id,x,y,nectar" << std::endl;
        auto cells = FLAMEGPU->agent("cell");
        auto& cell_pop = cells.getPopulationData();
        for (const auto& cell : cell_pop) {
            float nectar = cell.getVariable<float>("nectar");
            if (nectar > 0.0f) {
                flower_log << cell.getID() << ","
                           << cell.getVariable<int>("x") << ","
                           << cell.getVariable<int>("y") << ","
                           << nectar << "\n";
            }
        }
        flower_log.close();
    }

    float avg_hunger = bees.sum<float>("hunger_level") / (float)bees.count();
    std::cout << "Step: " << step 
              << " | Bee count: " << bees.count() 
              << " | Avg Hunger: " << avg_hunger << std::endl;
}

FLAMEGPU_EXIT_FUNCTION(exitLog) {
    if (bees_log.is_open()) {
        bees_log.close();
    }
}

void define_model(ModelDescription &model) {
    // Environment variables
    EnvironmentDescription env = model.Environment();
    env.newProperty<float>("WH", 0.6f);
    env.newProperty<float>("WW", 0.4f);

    // Cell Agent
    AgentDescription cell = model.newAgent("cell");
    cell.newVariable<int>("x");
    cell.newVariable<int>("y");
    cell.newVariable<int>("is_occupied", 0);
    cell.newVariable<float>("nectar", 0.0f);

    // Bee Agent
    AgentDescription bee = model.newAgent("bee");
    bee.newVariable<int>("x");
    bee.newVariable<int>("y");
    bee.newVariable<int>("last_x", -1);
    bee.newVariable<int>("last_y", -1);
    bee.newVariable<float>("hunger_level");
    bee.newVariable<int>("wait", 0);
    bee.newVariable<float>("priority", 0.0f);
    bee.newVariable<int>("target_x", -1);
    bee.newVariable<int>("target_y", -1);
    bee.newVariable<int>("last_flower_x", -1);
    bee.newVariable<int>("last_flower_y", -1);
    bee.newVariable<int>("is_at_flower", 0);
    bee.newVariable<int>("target_has_nectar", 0);
    bee.newVariable<int>("moved_this_step", 0);

    // Add movement submodel
    SubModelDescription movement_sub = add_movement_submodel(model);

    // Agent functions in parent model
    AgentFunctionDescription init_move = bee.newFunction("bee_init_movement", bee_init_movement);
    AgentFunctionDescription calc_priority = bee.newFunction("calculate_priority", calculate_priority);
    AgentFunctionDescription update_h_w = bee.newFunction("update_hunger_wait", update_hunger_wait);

    // Layers
    LayerDescription l0 = model.newLayer();
    l0.addAgentFunction(init_move);

    LayerDescription l1 = model.newLayer();
    l1.addAgentFunction(calc_priority);

    LayerDescription l2 = model.newLayer();
    l2.addSubModel(movement_sub); 

    LayerDescription l3 = model.newLayer();
    l3.addAgentFunction(update_h_w);

    // Initialisation functions
    model.addInitFunction(createAgent);
    model.addInitFunction(initLog);
    
    // Step function
    model.addStepFunction(stepLogger);

    // Exit function
    model.addExitFunction(exitLog);
}

int main(int argc, const char ** argv) {
    ModelDescription model("BeesFlowerModel");

    define_model(model);

    // Simulation configuration
    CUDASimulation simulation(model);
    simulation.SimulationConfig().random_seed = std::random_device{}();
    simulation.SimulationConfig().steps = SIMULATION_STEPS;
    
    simulation.simulate();

    return EXIT_SUCCESS;
}
