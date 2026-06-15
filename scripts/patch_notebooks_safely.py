import json
import os

def patch_notebook(nb_path, patches):
    if not os.path.exists(nb_path):
        return
    with open(nb_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    for cell in nb.get('cells', []):
        if cell.get('cell_type') == 'code':
            source = cell.get('source', [])
            context = "".join(source)
            new_source = []
            
            for line in source:
                # 1. Standard matplotlib savefig
                if "plt.show()" in line:
                    for keyword, filename in patches.items():
                        if keyword in context and f'plt.savefig("{filename}"' not in context:
                            indent = line[:line.find('plt.show()')]
                            new_source.append(f'{indent}plt.savefig("{filename}", dpi=dpi_plot, bbox_inches="tight")\n')
                            break
                
                # 2. NB 02 logic fixes
                if 'def profiles(ax, df_plot, mythema, color_dict=None):' in line:
                    new_source.append(line)
                    if 'if df_plot.empty' not in context:
                        new_source.append('    if df_plot.empty: print("Warning: df_plot is empty, skipping plot."); return\n')
                    continue
                
                if 'df_plot["elevation"] = savgol_filter(df_plot["elevation"], 5, 2)' in line:
                    if 'if len(df_plot["elevation"]) >= 5:' not in context:
                        indent = line[:line.find('df_plot')]
                        new_source.append(f'{indent}if len(df_plot["elevation"]) >= 5:\n')
                        new_source.append(f'    {line}')
                        continue
                
                new_source.append(line)

            # 3. Handle Holoviews (NB 01 Chord Diagram)
            if "chord =" in context and "hv.Chord" in context and 'hv.save(chord' not in context:
                new_source.append('\nhv.save(chord, "chord_diagram.png")\n')

            cell['source'] = new_source
            
    with open(nb_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, indent=1)

# Map unique keywords to filenames
nb01_patches = {
    'highway_query': 'highway1.png',
    'Figure 4a': 'sidewalk_py.png',
    'Figure 4b': 'hwfwfwsw_py.png',
    'sidewalk_unique as a,': 'unique_sidewalk_py.png', # Fig 5a
    '# Figure 5b.': 'mapping_approach_b.png',        # Fig 5b
    'surface_query': 'surface.png',
    'plt.imshow(graz_dem_data': 'dem_python_two.png',
    '# plotting the gradient': 'gradient_plot_py.png',
    'sns.boxplot(y=all_slope': 'slope_all_boxplot.png',
    'sns.histplot(all_slope': 'slope_all_heighdata.png',
    'sns.boxplot(data=compare_slope': 'slope1_boxplot.png',
    'sns.histplot(data=compare_slope': 'slope1_hist.png',
    '# Hexagon map of steps': 'hex_steps_py.png',
    'query_kerb_height': 'kerb_height.png',
    'query_width': 'width.png',
    '# barriers in Graz': 'barriers.png'
}

nb02_patches = {
    'bbox_from_centerpoint(Point(15.4509517, 47.0651107)': 'experiment1_TUGRAZ.png',
    'profiles(ax1, pedestrian_exp_1, "highway")': 'experiment1_TUGraz_elvprofile_ped.png',
    'ax.axis("off")': 'experiment2_Park.png',
    'profiles(ax3, wheelchair_exp2, "slope_treshhold"': 'experiment2_Park_elvprofile_wheel.png',
    'profiles(ax3, pedestrian_exp2, "slope_treshhold"': 'experiment2_Park_elvprofile_ped.png'
}

nb03_patches = {
    '# Figure 22. Overview Map Experiment 3': 'performance_test.png',
    '# Figure 23. Detailed Surface Conditions': 'surface_performance.png'
}

nb04_patches = {
    'fig.suptitle("Street Network"': 'comp_street_network.png',
    'fig.suptitle("sidewalk=*"': 'comp_sidewalk_any.png',
    'fig.suptitle("highway=footway + footway=sidewalk"': 'comp_highway_footway.png',
    'fig.suptitle("Sidewalk unique"': 'comp_sidewalk_unique.png',
    'fig.suptitle("Steps Comparison"': 'comp_steps.png'
}

if __name__ == "__main__":
    patch_notebook('repro/01_fire_horse.ipynb', nb01_patches)
    patch_notebook('repro/02_fire_horse.ipynb', nb02_patches)
    patch_notebook('repro/03_fire_horse.ipynb', nb03_patches)
    patch_notebook('repro/04_fire_horse.ipynb', nb04_patches)
