extends Object
class_name ImageUtils

enum ImgType {
	JPG,PNG,BMP,WEBP,Unknown
}

# determines image file type based on contents of data buffer
# this can be used in conjuction with Godot Image.load_*_from_buffer()
static func get_img_type_from_buffer(data: PoolByteArray):
	# detect jpeg first since it's probably most common
	if data.size() >= 2 and data[0] == 0xff and data[1] == 0xd8:
		return ImgType.JPG
		
	# detect PNG by sequence of [137,80,78,71,13,10,26,10]
	if data.size() >= 8 && data[0] == 137 && data[1] == 80 && data[2] == 78 && data[3] == 71 && data[4] == 13 && data[5] == 10 && data[6] == 26 && data[7] == 10:
		return ImgType.PNG
		
	# detect BMP by first two chars are 'B' and 'M'
	if data.size() >= 2 && data[0] == 0x42 && data[1] == 0x4d:
		# could parse next 4 bytes (little endian) and compare to filesize
		return ImgType.BMP
	
	# detect WEBP by looking for "WEBP" as offset 8
	if data.size() >= 12 && data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50:
		return ImgType.WEBP
	
	return ImgType.Unknown
	
# returns a parsed Image object or null if parsing failed
static func get_img_from_buffer(data: PoolByteArray):
	var img = Image.new()
	
	match get_img_type_from_buffer(data):
		ImgType.JPG:
			img.load_jpg_from_buffer(data)
		ImgType.PNG:
			img.load_png_from_buffer(data)
		ImgType.BMP:
			img.load_bmp_from_buffer(data)
		ImgType.WEBP:
			img.load_webp_from_buffer(data)
		_:
			img = null
			
	return img
