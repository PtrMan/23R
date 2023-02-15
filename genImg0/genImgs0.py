import math

from PIL import Image

sprite0 = Image.open('./sprite0.png', 'r')
sprite0 = sprite0.convert('RGBA')
#print(img)

#img_w, img_h = img.size


for itFrame in range(15):
    canvas = Image.new('RGBA', (128, 80), (0, 0, 0, 255))
    #bg_w, bg_h = canvas.size
    #offset = ((bg_w - img_w) // 2, (bg_h - img_h) // 2)
    
    if False: # linear motion TEST
        offset = (10+itFrame*5, 10+itFrame*3)
    else:
        offset = (50.0+math.cos(itFrame * 0.08)*20.0, 30.0+math.sin(itFrame * 0.08)*20.0)
    
    offset = (int(offset[0]), int(offset[1]))

    resizedSprite = sprite0.resize((20,20))
    canvas.paste(resizedSprite, offset)

    filename = str(itFrame).zfill(5)+'.png'
    canvas.save(filename)

