import matplotlib.pyplot as plt
import numpy as np

def visualize():
    # Load data
    try:
        # Load bees_log.csv using numpy
        # Header: step,id,x,y,hunger,wait,at_flower
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
    hunger = bees_data[:, 4]
    wait = bees_data[:, 5]

    flower_x = flowers_data[:, 1]
    flower_y = flowers_data[:, 2]

    unique_steps = np.unique(step).astype(int)

    # 1. Plot Average Hunger and Wait over time
    avg_hunger = []
    avg_wait = []
    for s in unique_steps:
        mask = step == s
        avg_hunger.append(np.mean(hunger[mask]))
        avg_wait.append(np.mean(wait[mask]))
    
    fig, ax1 = plt.subplots(figsize=(10, 6))
    
    ax1.set_xlabel('Step')
    ax1.set_ylabel('Avg Hunger', color='tab:red')
    ax1.plot(unique_steps, avg_hunger, color='tab:red', label='Avg Hunger')
    ax1.tick_params(axis='y', labelcolor='tab:red')
    
    ax2 = ax1.twinx()
    ax2.set_ylabel('Avg Wait', color='tab:blue')
    ax2.plot(unique_steps, avg_wait, color='tab:blue', label='Avg Wait')
    ax2.tick_params(axis='y', labelcolor='tab:blue')
    
    plt.title('Average Bee Hunger and Wait over Time')
    fig.tight_layout()
    plt.savefig('hunger_wait_plot.png')
    print("Saved hunger_wait_plot.png")

    # 2. Movement snapshots
    steps_to_plot = [0, 25, 50, 75, 99]
    # Filter steps that actually exist
    steps_to_plot = [s for s in steps_to_plot if s in unique_steps]
    
    fig, axes = plt.subplots(1, len(steps_to_plot), figsize=(20, 4))
    if len(steps_to_plot) == 1:
        axes = [axes]
    
    for i, s in enumerate(steps_to_plot):
        ax = axes[i]
        mask = step == s
        
        # Plot flowers
        ax.scatter(flower_x, flower_y, c='green', marker='*', s=50, alpha=0.5, label='Flowers')
        
        # Plot bees
        ax.scatter(bee_x[mask], bee_y[mask], c='orange', marker='o', s=20, label='Bees')
        
        ax.set_title(f'Step {s}')
        ax.set_xlim(0, 100)
        ax.set_ylim(0, 100)
        if i == 0:
            ax.legend(loc='upper right')

    plt.suptitle('Bee and Flower Positions over Time')
    plt.tight_layout()
    plt.savefig('movement_snapshots.png')
    print("Saved movement_snapshots.png")

    # 3. Individual bee trajectories (sample 5 bees)
    plt.figure(figsize=(10, 10))
    unique_ids = np.unique(bee_id)
    sample_ids = unique_ids[:5]
    plt.scatter(flower_x, flower_y, c='green', marker='*', s=100, alpha=0.3)
    
    for bid in sample_ids:
        mask = bee_id == bid
        # sort by step just in case
        idx = np.argsort(step[mask])
        plt.plot(bee_x[mask][idx], bee_y[mask][idx], marker='.', alpha=0.6, label=f'Bee {int(bid)}')
        # Mark start and end
        plt.scatter(bee_x[mask][idx][0], bee_y[mask][idx][0], marker='o', c='blue', s=30)
        plt.scatter(bee_x[mask][idx][-1], bee_y[mask][idx][-1], marker='x', c='red', s=30)

    plt.title('Sample Bee Trajectories')
    plt.xlabel('X')
    plt.ylabel('Y')
    plt.xlim(0, 100)
    plt.ylim(0, 100)
    plt.legend()
    plt.savefig('bee_trajectories.png')
    print("Saved bee_trajectories.png")

if __name__ == "__main__":
    visualize()
