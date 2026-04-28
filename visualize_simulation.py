import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.colors import ListedColormap

def animate_simulation():
    try:
        # Load agents_log.csv using numpy
        agents_data = np.genfromtxt('agents_log.csv', delimiter=',', skip_header=1)
        if agents_data.size == 0:
            print("Error: agents_log.csv is empty")
            return
    except Exception as e:
        print(f"Error loading agents_log.csv: {e}")
        return

    # Extract simulation parameters
    steps = int(np.max(agents_data[:, 0])) + 1
    env_dim = 100

    # Setup the figure and axis
    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_xlim(0, env_dim)
    ax.set_ylim(0, env_dim)
    ax.set_title('Moving Agents Simulation')

    # Create a scatter plot for agents
    agent_scatter = ax.scatter([], [], c='blue', s=10, label='Agents')
    
    # Text for current step
    step_text = ax.text(0.02, 0.95, '', transform=ax.transAxes)

    def init():
        agent_scatter.set_offsets(np.empty((0, 2)))
        step_text.set_text('')
        return agent_scatter, step_text

    def update(frame):
        # Filter data for the current step
        step_data = agents_data[agents_data[:, 0] == frame]
        
        # Update agent positions
        if step_data.size > 0:
            agent_scatter.set_offsets(step_data[:, 2:4])
        
        step_text.set_text(f'Step: {frame}')
        return agent_scatter, step_text

    # Create the animation
    ani = animation.FuncAnimation(fig, update, frames=steps,
                                 init_func=init, blit=True, interval=100)

    plt.legend()
    plt.show()

if __name__ == "__main__":
    animate_simulation()
