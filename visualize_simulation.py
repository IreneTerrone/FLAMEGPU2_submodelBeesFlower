import matplotlib.pyplot as plt
import numpy as np

def visualize():
    # Load data
    try:
        # Load bees_log.csv using numpy
        # Header: step,id,x,y,hunger_level,wait,at_flower
        bees_data = np.genfromtxt('bees_log.csv', delimiter=',', skip_header=1)
        # Load flowers_log.csv using numpy
        # Header: id,x,y,nectar
        flowers_data = np.genfromtxt('flowers_log.csv', delimiter=',', skip_header=1)
    except Exception as e:
        print(f"Error loading logs: {e}")
        return

    # Extract columns
    step = bees_data[:, 0]
    bee_id = bees_data[:, 1]
    bee_x = bees_data[:, 2]
    bee_y = bees_data[:, 3]
    hunger_level = bees_data[:, 4]
    wait = bees_data[:, 5]
    at_flower = bees_data[:, 6]

    flower_x = flowers_data[:, 1]
    flower_y = flowers_data[:, 2]

    unique_steps = np.unique(step)

    # 1. Plot Average Hunger Level and Wait over time
    avg_hunger = []
    avg_wait = []
    for s in unique_steps:
        mask = (step == s)
        avg_hunger.append(np.mean(hunger_level[mask]))
        avg_wait.append(np.mean(wait[mask]))

    fig, ax1 = plt.subplots(figsize=(10, 6))

    ax1.set_xlabel('Step')
    ax1.set_ylabel('Avg Hunger Level', color='tab:red')
    ax1.plot(unique_steps, avg_hunger, color='tab:red', label='Avg Hunger Level')
    ax1.tick_params(axis='y', labelcolor='tab:red')

    ax2 = ax1.twinx()
    ax2.set_ylabel('Avg Wait', color='tab:blue')
    ax2.plot(unique_steps, avg_wait, color='tab:blue', label='Avg Wait')
    ax2.tick_params(axis='y', labelcolor='tab:blue')

    plt.title('Average Bee Hunger Level and Wait over Time')
    fig.tight_layout()
    plt.savefig('hunger_wait_plot.png')
    print("Saved hunger_wait_plot.png")


    # 2. Movement snapshots
    steps_to_plot = [0, 25, 50, 75, 99]
    steps_to_plot = [s for s in steps_to_plot if s in unique_steps]
    
    fig, axes = plt.subplots(1, len(steps_to_plot), figsize=(20, 4))
    if len(steps_to_plot) == 1:
        axes = [axes]
    
    for i, s in enumerate(steps_to_plot):
        ax = axes[i]
        mask = step == s
        
        # Plot flowers
        ax.scatter(flower_x, flower_y, c='green', marker='*', s=30, alpha=0.3, label='Flowers')
        
        # Plot bees
        ax.scatter(bee_x[mask], bee_y[mask], c='orange', marker='o', s=5, label='Bees')
        
        ax.set_title(f'Step {s}')
        ax.set_xlim(0, 100)
        ax.set_ylim(0, 100)
        if i == 0:
            ax.legend(loc='upper right')

    plt.suptitle('Bee and Flower Positions over Time (Full Grid)')
    plt.tight_layout()
    plt.savefig('movement_snapshots.png')
    print("Saved movement_snapshots.png")

    # 2.5 Zoomed Snapshots (to see collision avoidance)
    fig, axes = plt.subplots(1, len(steps_to_plot), figsize=(20, 4))
    if len(steps_to_plot) == 1:
        axes = [axes]
    
    zoom_range = (40, 60) # Central 20x20 area
    
    for i, s in enumerate(steps_to_plot):
        ax = axes[i]
        mask = (step == s) & (bee_x >= zoom_range[0]) & (bee_x <= zoom_range[1]) & (bee_y >= zoom_range[0]) & (bee_y <= zoom_range[1])
        flower_mask = (flower_x >= zoom_range[0]) & (flower_x <= zoom_range[1]) & (flower_y >= zoom_range[0]) & (flower_y <= zoom_range[1])
        
        # Grid lines to see individual cells
        ax.set_xticks(np.arange(zoom_range[0], zoom_range[1] + 1, 1), minor=True)
        ax.set_yticks(np.arange(zoom_range[0], zoom_range[1] + 1, 1), minor=True)
        ax.grid(which='minor', alpha=0.3)
        
        # Plot flowers
        ax.scatter(flower_x[flower_mask], flower_y[flower_mask], c='green', marker='*', s=150, alpha=0.4)
        
        # Plot bees
        ax.scatter(bee_x[mask], bee_y[mask], c='orange', marker='o', s=50)
        
        ax.set_title(f'Step {s} (Zoom)')
        ax.set_xlim(zoom_range[0], zoom_range[1])
        ax.set_ylim(zoom_range[0], zoom_range[1])

    plt.suptitle('Zoomed Area (40-60) - One Bee Per Cell Verification')
    plt.tight_layout()
    plt.savefig('movement_snapshots_zoomed.png')
    print("Saved movement_snapshots_zoomed.png")

    # 3. Individual bee trajectories (sample 50 bees)
    plt.figure(figsize=(10, 10))
    unique_ids = np.unique(bee_id)
    sample_ids = unique_ids[:50] # Increased from 5 to 50
    plt.scatter(flower_x, flower_y, c='green', marker='*', s=100, alpha=0.3)
    
    for bid in sample_ids:
        mask = (bee_id == bid)
        # sort by step
        idx = np.argsort(step[mask])
        plt.plot(bee_x[mask][idx], bee_y[mask][idx], marker='.', alpha=0.4, linewidth=0.5)
        # Mark start and end
        plt.scatter(bee_x[mask][idx][0], bee_y[mask][idx][0], marker='o', c='blue', s=10)
        plt.scatter(bee_x[mask][idx][-1], bee_y[mask][idx][-1], marker='x', c='red', s=10)

    plt.title('Sample Bee Trajectories (50 Bees)')
    plt.xlabel('X')
    plt.ylabel('Y')
    plt.xlim(0, 100)
    plt.ylim(0, 100)
    plt.savefig('bee_trajectories.png')
    print("Saved bee_trajectories.png")

if __name__ == "__main__":
    visualize()
