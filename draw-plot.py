import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import os
import sys
from os.path import basename, splitext

def parse_file(filepath):
    data = []
    scenario = splitext(basename(filepath))[0]
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                key, values = line.split(': ')
                N, mean, std = values.split(', ')
                data.append({
                    'metric': key,
                    'N': float(N.split('=')[1]),
                    'mean': float(mean.split('=')[1]),
                    'std': float(std.split('=')[1]),
                    'scenario': scenario
                })
    df = pd.DataFrame(data)
    return df.reset_index(drop=True) # reset index here

buffer_size = sys.argv[1]
files = sys.argv[2:]
data = pd.concat([parse_file(file) for file in files])

metrics = ['elapsed', 'sys', 'user', 'maxrss', 'voluntarycs', 'involuntarycs']
units = ['seconds', 'seconds', 'seconds', 'kb', 'counts', 'counts']

import seaborn as sns

for metric, unit in zip(metrics, units):
    plt.figure(figsize=(10, 6))
    metric_data = data[data['metric'] == metric]
    bplot = sns.barplot(x='scenario', y='mean', yerr=metric_data['std'], data=metric_data)
    # plt.title(f'Mean and Standard deviation of {metric} by scenario')


    # Adjust bar widths
    for patch in bplot.patches:
        current_width = patch.get_width()
        diff = current_width - .3  # Desired width is 0.3

        # Center the bar and adjust the width
        patch.set_width(.3)
        patch.set_x(patch.get_x() + diff * .5)

    plt.ylabel(f'{metric} ({unit})')  # Here, replace 'unit of your measurement' with actual unit
    
    os.makedirs(buffer_size, exist_ok = True)
    plt.savefig(f'{buffer_size}/{metric}_bar.png')
