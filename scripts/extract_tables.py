import json
import re
import sys
import os

def process_table(tex_str):
    # Extract only the tabular part
    match = re.search(r'(\\begin\{tabular\}.*?\\end\{tabular\})', tex_str, re.DOTALL)
    if match:
        tex_str = match.group(1)
    
    # Escape underscores (but not already escaped ones)
    tex_str = re.sub(r'(?<!\\)_', r'\\_', tex_str)
    
    # Round floats with 3 or more decimal places to 2 decimal places
    def round_match(m):
        return f"{float(m.group(0)):.2f}"
    tex_str = re.sub(r'\d+\.\d{3,}', round_match, tex_str)
    
    # Escape special character #
    tex_str = tex_str.replace('#', '\\#')
    
    # Shorten long headers for Table 13 if present
    tex_str = tex_str.replace('graz\\_pgr\\_1500m', 'Graz')
    tex_str = tex_str.replace('linz\\_pgr\\_1500m', 'Linz')
    tex_str = tex_str.replace('salzburg\\_pgr\\_1500m', 'Salzb.')
    
    # Wrap in center and resizebox to ensure it fits the page
    tex_str = "\\begin{center}\n\\footnotesize\n\\resizebox{\\textwidth}{!}{\n" + tex_str + "\n}\n\\end{center}"
    
    return tex_str

def extract_from_notebook(notebook_path):
    if not os.path.exists(notebook_path):
        return []
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)

    results = []
    for cell in nb.get('cells', []):
        if cell.get('cell_type') == 'code':
            for out in cell.get('outputs', []):
                if 'text' in out:
                    text = "".join(out['text'])
                    matches = re.findall(r'\\begin\{tabular\}.*?\\end\{tabular\}', text, re.DOTALL)
                    results.extend(matches)
    return results

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repro_dir = os.path.join(script_dir, '../repro')
    
    # Notebook 03: Tables 10, 11, 12
    nb03 = os.path.join(repro_dir, 'executed_03_fire_horse.ipynb')
    tables03 = extract_from_notebook(nb03)
    if len(tables03) >= 3:
        with open(f'{repro_dir}/table_11_highway.tex', 'w') as f:
            f.write(process_table(tables03[0]))
        with open(f'{repro_dir}/table_10_surface.tex', 'w') as f:
            f.write(process_table(tables03[1]))
        with open(f'{repro_dir}/table_12_kerbs.tex', 'w') as f:
            f.write(process_table(tables03[2]))
        print(f"Extracted 3 tables from Notebook 03")

    # Notebook 04: Table 13
    nb04 = os.path.join(repro_dir, 'executed_04_fire_horse.ipynb')
    tables04 = extract_from_notebook(nb04)
    if len(tables04) >= 1:
        with open(f'{repro_dir}/table_13_city_comparison.tex', 'w') as f:
            f.write(process_table(tables04[0]))
        print(f"Extracted 1 table from Notebook 04")

if __name__ == '__main__':
    main()
