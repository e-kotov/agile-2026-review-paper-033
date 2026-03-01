import json
import re
import sys

def extract_and_clean_tables(notebook_path, output_dir):
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)

    tables = []
    
    # Locate the cell with the table output
    for cell in nb.get('cells', []):
        if cell.get('cell_type') == 'code':
            for out in cell.get('outputs', []):
                if 'text' in out:
                    text_lines = out['text']
                    if any('begin{table}' in line for line in text_lines):
                        # Join the list of text lines into a single string
                        full_text = "".join(text_lines)
                        # Split by empty lines between tables
                        table_blocks = [t.strip() for t in full_text.split('\\end{table}') if '\\begin{table}' in t]
                        # append end{table} back
                        tables = [t + '\n\\end{table}' for t in table_blocks]

    if not tables or len(tables) < 3:
        print(f"Error: Expected at least 3 tables, found {len(tables)}", file=sys.stderr)
        sys.exit(1)

    # Process and save each table
    def process_table(tex_str):
        # Extract only the tabular part
        match = re.search(r'(\\begin\{tabular\}.*?\\end\{tabular\})', tex_str, re.DOTALL)
        if match:
            tex_str = match.group(1)

        # Force standard column definitions
        # First, remove any custom specs like p{...}
        tex_str = re.sub(r'p\{.*?\}', 'r', tex_str)
        # Then replace the start of the tabular with our desired compact format
        tex_str = re.sub(r'\\begin\{tabular\}\{\|?.*?\|?\}', r'\\begin{tabular}{|l|r|r|r|}', tex_str, count=1)
        
        # Convert booktabs to standard borders
        tex_str = tex_str.replace('\\toprule', '\\hline')
        tex_str = tex_str.replace('\\midrule', '\\hline')
        tex_str = tex_str.replace('\\bottomrule', '\\hline')
        
        # Escape underscores
        tex_str = re.sub(r'(?<!\\)_', r'\\_', tex_str)
        
        # Wrap in center environment for better PDF layout
        tex_str = f"\\begin{{center}}\n{tex_str}\n\\end{{center}}"
        
        return tex_str

    # Table 11: Highway (first table output)
    with open(f'{output_dir}/table_11_highway.tex', 'w') as f:
        f.write(process_table(tables[0]))
        
    # Table 10: Surface (second table output)
    with open(f'{output_dir}/table_10_surface.tex', 'w') as f:
        f.write(process_table(tables[1]))
        
    # Table 12: Kerbs (third table output)
    with open(f'{output_dir}/table_12_kerbs.tex', 'w') as f:
        f.write(process_table(tables[2]))

    print(f"Successfully extracted {len(tables)} tables to {output_dir}")

if __name__ == '__main__':
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    notebook = os.path.join(script_dir, '../repro/executed_03_routing_analysis.ipynb')
    out_dir = os.path.join(script_dir, '../repro')
    extract_and_clean_tables(notebook, out_dir)
