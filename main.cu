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
    
    for (const auto& bee : bee_pop) {
        bees_log << step << ","
                 << bee.getID() << ","
                 << bee.getVariable<float>("x") << ","
                 << bee.getVariable<float>("y") << ","
                 << bee.getVariable<float>("hunger_level") << ","
                 << bee.getVariable<int>("wait") << ","
                 << bee.getVariable<int>("at_flower") << "\n";
    }
    
    // Log flowers once at the start to know where they are
    if (step == 0) {
        std::ofstream flower_log("flowers_log.csv");
        flower_log << "id,x,y,nectar" << std::endl;
        auto flowers = FLAMEGPU->agent("flower");
        auto& flower_pop = flowers.getPopulationData();
        for (const auto& flower : flower_pop) {
            flower_log << flower.getID() << ","
                       << flower.getVariable<float>("x") << ","
                       << flower.getVariable<float>("y") << ","
                       << flower.getVariable<float>("nectar") << "\n";
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

    // Flower Agent
    AgentDescription flower = model.newAgent("flower");
    flower.newVariable<id_t>("id", ID_NOT_SET);
    flower.newVariable<float>("x");
    flower.newVariable<float>("y");
    flower.newVariable<float>("nectar");

    // Bee Agent
    AgentDescription bee = model.newAgent("bee");
    bee.newVariable<id_t>("id", ID_NOT_SET);
    bee.newVariable<float>("x");
    bee.newVariable<float>("y");
    bee.newVariable<float>("hunger_level");
    bee.newVariable<int>("wait", 0);
    bee.newVariable<float>("priority", 0.0f);
    bee.newVariable<float>("target_x");
    bee.newVariable<float>("target_y");
    bee.newVariable<id_t>("target_flower_id", ID_NOT_SET);
    bee.newVariable<int>("at_flower", 0);
    bee.newVariable<id_t>("last_flower_id", ID_NOT_SET);
    bee.newVariable<int>("is_moving", 0);
    

    // Add movement submodel
    SubModelDescription movement_sub = add_movement_submodel(model);
    movement_sub.setMaxSteps(1); 

    // Agent functions in parent model
    AgentFunctionDescription calc_priority = bee.newFunction("calculate_priority", calculate_priority);
    AgentFunctionDescription receive_grant = bee.newFunction("bee_receive_grant", bee_receive_grant);
    AgentFunctionDescription update_h_w = bee.newFunction("update_hunger_wait", update_hunger_wait);

    // Layers
    LayerDescription l1 = model.newLayer();
    l1.addAgentFunction(calc_priority);

    LayerDescription l2 = model.newLayer();
    l2.addSubModel(movement_sub); 

    LayerDescription l3 = model.newLayer();
    l3.addAgentFunction(receive_grant);

    LayerDescription l4 = model.newLayer();
    l4.addAgentFunction(update_h_w);

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
    simulation.SimulationConfig().steps = SIMULATION_STEPS;
    
    simulation.simulate();

    return EXIT_SUCCESS;
}
