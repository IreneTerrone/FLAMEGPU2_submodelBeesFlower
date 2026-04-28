#include <iostream>
#include <fstream>
#include "flamegpu/flamegpu.h"
#include "movesubAPI_mock.cuh"

void define_model(flamegpu::ModelDescription &model) {
    // Parent Agent (Bee)
    flamegpu::AgentDescription bee = model.newAgent("bee");
    bee.newState("foraging"); // Participating state
    bee.newState("resting");  // Non-participating state
    
    bee.newVariable<int>("x");
    bee.newVariable<int>("y");
    bee.newVariable<float>("priority_main", 0.0f);
    bee.newVariable<int>("target_x");
    bee.newVariable<int>("target_y");
    bee.newVariable<int>("moved_this_step");

    // Initialize the Movement SubModel
    auto move_sub = Stock::SubModels::Movement(model);

    /**
     * Selective State Mapping:
     * - We map the parent "foraging" state to the internal "active" state.
     * - The parent "resting" state is NOT mapped, so resting bees won't move.
     */
    move_sub.setAgent("movingAgent", "bee", 
        {
            {"x", "x"},
            {"y", "y"},
            {"target_x", "target_x"},
            {"target_y", "target_y"},
            {"moved_this_step", "moved_this_step"},
            {"priority", "priority_main"}
        },
        {
            {"active", "foraging"} // State mapping
        }
    );

    // Add to the main model's execution layers
    model.newLayer().addSubModel(move_sub);
}

int main(int argc, const char ** argv) {
    flamegpu::ModelDescription model("MovementMockModel");
    define_model(model);
    std::cout << "Mockup with Movement submodel and State Mapping defined successfully." << std::endl;
    return EXIT_SUCCESS;
}
