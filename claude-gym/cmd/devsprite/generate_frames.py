import sys
from PIL import Image

def img_to_ansi(img_path, out_file):
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    
    out = []
    # Simple clear screen and place cursor to keep the console clean
    # out.append("\033[2J\x1b[H")
    for y in range(0, h, 2):
        row = ""
        for x in range(w):
            r1, g1, b1, a1 = img.getpixel((x, y))
            
            r2, g2, b2, a2 = (0,0,0,0)
            if y + 1 < h:
                r2, g2, b2, a2 = img.getpixel((x, y + 1))
            
            if a1 < 128 and a2 < 128:
                row += "\033[0m "
            elif a1 >= 128 and a2 < 128:
                row += f"\033[38;2;{r1};{g1};{b1}m▀"
            elif a1 < 128 and a2 >= 128:
                row += f"\033[38;2;{r2};{g2};{b2}m▄"
            else:
                row += f"\033[38;2;{r1};{g1};{b1};48;2;{r2};{g2};{b2}m▀"
        row += "\033[0m"
        out.append(row)
    
    with open(out_file, "w") as f:
        f.write("\n".join(out))

img_to_ansi("/Users/mbp/Code/claude-prison/claude-gym/assets/developer/chair_dips_f00_preview.png", "/Users/mbp/Code/claude-prison/claude-gym/assets/developer/chair_dips_f00_preview.ansi")

