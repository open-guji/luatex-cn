#!/usr/bin/env python3
"""
将印章图片转换为指定颜色并添加做旧效果
使用方法: python convert_seal_color.py
"""

from PIL import Image, ImageFilter
import os
import random
import math

# 目标颜色 (RGB) - 较浅的朱砂色
TARGET_COLOR = (188, 50, 45)

# 输入和输出文件
input_file = "文渊阁宝印.png"
output_file = "文渊阁宝印-彩色.png"

def add_aging_effect(img, intensity=0.5):
    """添加强烈的做旧效果：大面积磨损、斑驳"""
    pixels = img.load()
    width, height = img.size
    
    # 预先生成一些大的磨损区域中心点
    num_worn_areas = int(width * height * 0.0001)  # 更多磨损区域
    worn_centers = [(random.randint(0, width-1), random.randint(0, height-1), 
                     random.randint(5, 30)) for _ in range(num_worn_areas)]
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            if a > 0:  # 只处理非透明像素
                # 1. 计算是否在大磨损区域内
                in_worn_area = False
                for cx, cy, radius in worn_centers:
                    dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                    if dist < radius:
                        in_worn_area = True
                        # 中心磨损更严重
                        wear_factor = 1 - (dist / radius) * 0.5
                        a = max(0, int(a * (1 - wear_factor * 0.8)))
                        break
                
                # 2. 随机减淡 - 模拟褪色（更强）
                fade_factor = random.uniform(0.7, 1.0)
                r = int(r * fade_factor)
                g = int(g * fade_factor)
                b = int(b * fade_factor)
                
                # 3. 边缘更强的磨损
                if a < 230:
                    if random.random() < 0.5:
                        a = max(0, a - random.randint(30, 100))
                
                # # 4. 随机小孔洞 - 更多更大
                # if random.random() < intensity * 0.08:
                #     a = max(0, a - random.randint(80, 255))
                
                # # 5. 细小的噪点纹理
                # if random.random() < 0.3:
                #     noise = random.randint(-25, 25)
                #     r = max(0, min(255, r + noise))
                #     g = max(0, min(255, g + noise))
                #     b = max(0, min(255, b + noise))
                
                # pixels[x, y] = (r, g, b, a)
    
    return img

def convert_to_color(input_path, output_path, target_rgb, add_aging=True):
    """将图片转换为指定颜色，保留透明度"""
    img = Image.open(input_path).convert("RGBA")
    pixels = img.load()
    width, height = img.size
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            # 只要不透明，就直接使用目标颜色
            if a > 0:
                pixels[x, y] = (target_rgb[0], target_rgb[1], target_rgb[2], a)
    
    # 添加做旧效果
    if add_aging:
        img = add_aging_effect(img, intensity=0.6)  # 更强的磨损
    
    img.save(output_path, "PNG")
    print(f"已转换: {input_path} -> {output_path}")
    print(f"目标颜色: RGB{target_rgb}")
    if add_aging:
        print("已添加强烈做旧效果（大面积磨损、斑驳）")

if __name__ == "__main__":
    if os.path.exists(input_file):
        convert_to_color(input_file, output_file, TARGET_COLOR, add_aging=False)
    else:
        print(f"错误: 找不到文件 {input_file}")