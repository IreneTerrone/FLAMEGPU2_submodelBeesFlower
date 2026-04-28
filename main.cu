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
std::ofstream agents_log;

FLAMEGPU_INIT_FUNCTION(initLog) {
    agents_log.open("agents_log.csv");
    agents_log << "step,id,x,y,wait" << std::endl;
}

FLAMEGPU_STEP_FUNCTION(stepLogger) {
    auto movingAgents = FLAMEGPU->agent("movingAgent", "active");
    auto& agent_pop = movingAgents.getPopulationData();
    unsigned int step = FLAMEGPU->getStepCounter();
    
    // Validation: Check for collisions
    std::vector<int> occupancy(ENV_DIM * ENV_DIM, 0);
    int collisions = 0;

    for (const auto& agent : agent_pop) {
        int x = agent.getVariable<int>("x");
        int y = agent.getVariable<int>("y");

        int idx = x * ENV_DIM + y;
        occupancy[idx]++;
        if (occupancy[idx] > 1) {
            collisions++;
        }

        agents_log << step << ","
                 << agent.getID() << ","
                 << x << ","
                 << y << ","
                 << agent.getVariable<int>("wait") << "\n";
    }

    if (collisions > 0) {
        std::cerr << "!!! STEP " << step << ": DETECTED " << collisions << " COLLISIONS !!!" << std::endl;
    }
    
    std::cout << "Step: " << step 
              << " | Agent count: " << movingAgents.count() 
              << " | Collisions: " << collisions << std::endl;
}

FLAMEGPU_EXIT_FUNCTION(exitLog) {
    if (agents_log.is_open()) {
        agents_log.close();
    }
}

void define_model(ModelDescription &model) {
    // movingAgent Agent
    AgentDescription movingAgent = model.newAgent("movingAgent");
    movingAgent.newState("active"); // Added explicit state
    movingAgent.newVariable<int>("x");
    movingAgent.newVariable<int>("y");
    movingAgent.newVariable<int>("wait", 0);
    movingAgent.newVariable<float>("priority", 0.0f);
    movingAgent.newVariable<int>("target_x", -1);
    movingAgent.newVariable<int>("target_y", -1);
    movingAgent.newVariable<int>("moved_this_step", 0);

    // Add movement submodel
    SubModelDescription movement_sub = add_movement_submodel(model);

    // Agent functions in parent model
    AgentFunctionDescription calc_priority = movingAgent.newFunction("calculate_priority", calculate_priority);
    calc_priority.setInitialState("active");
    calc_priority.setEndState("active");

    AgentFunctionDescription upd_wait = movingAgent.newFunction("update_wait_status", update_wait_status);
    upd_wait.setInitialState("active");
    upd_wait.setEndState("active");

    // Layers
    LayerDescription l0 = model.newLayer();
    l0.addAgentFunction(calc_priority);

    LayerDescription l1 = model.newLayer();
    l1.addSubModel(movement_sub); 

    LayerDescription l2 = model.newLayer();
    l2.addAgentFunction(upd_wait);

    // Initialisation functions
    model.addInitFunction(createAgent);
    model.addInitFunction(initLog);
    
    // Step function
    model.addStepFunction(stepLogger);

    // Exit function
    model.addExitFunction(exitLog);
}

int main(int argc, const char ** argv) {
    ModelDescription model("OneAgentMovingModel");

    define_model(model);

    // Simulation configuration
    CUDASimulation simulation(model);
    simulation.SimulationConfig().random_seed = std::random_device{}();
    simulation.SimulationConfig().steps = SIMULATION_STEPS;
    
    simulation.simulate();

    return EXIT_SUCCESS;
}
