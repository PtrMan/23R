from PIL import Image

sprite0 = Image.open('./sprite0.png', 'r')
sprite0 = sprite0.convert('RGBA')
#print(img)

#img_w, img_h = img.size


for itFrame in range(15):
    canvas = Image.new('RGBA', (128, 80), (0, 0, 0, 255))
    #bg_w, bg_h = canvas.size
    #offset = ((bg_w - img_w) // 2, (bg_h - img_h) // 2)
    offset = (10+int(itFrame*5), 10)

    resizedSprite = sprite0.resize((20,20))
    canvas.paste(resizedSprite, offset)

    filename = str(itFrame).zfill(5)+'.png'
    canvas.save(filename)

