// vim: set et ts=4 sw=4:

#include "types.h"
#include "machine/io_port.h"
#include "device/vesagraphics.h"
#include "upng/upng.h"
//#include "EarlyIO.h"

extern "C" char startup;
extern "C" char ___IMG_END___;

extern "C" uintptr_t bumpStart;
static void* bumpAlloc(uintptr_t size)
{
	size = (size + 64) & (~((uintptr_t)0x3F));
	void *out = (void*)bumpStart;
	bumpStart += size;

	return out;
}

void* malloc(size_t size)
{
	void *out = bumpAlloc(size);
	//EarlyIO::print("malloc(");
	//EarlyIO::putNum(size);
	//EarlyIO::print(") = 0x");
	//EarlyIO::putNum((uintptr_t)out);
	//EarlyIO::print("\n");
	return out;
}

void free(void *ptr)
{
	(void)ptr;
}

static uint8_t interp(uint8_t *grayImg, uint32_t x, uint32_t y, uint32_t fromWidth, uint32_t fromHeight, uint32_t toWidth, uint32_t toHeight)
{
	uint32_t destX = (x * fromWidth) / toWidth;
	uint32_t destY = (y * fromHeight) / toHeight;

	if(destX >= fromWidth) {
		destX = fromWidth - 1;
	}
	if(destY >= fromHeight) {
		destY = fromHeight - 1;
	}

	return grayImg[destY * fromWidth + destX];
}

static void pitDelay(unsigned int wraparounds)
{
	for (unsigned int i = 0; i < wraparounds; i++) {
		unsigned int curr_count, prev_count = ~0;
		int delta;

		IO_Port port1(0x43);
		IO_Port port2(0x40);
		port1.outb(0x00);
		curr_count = port2.inb();
		curr_count |= port2.inb() << 8;

		do {
			prev_count = curr_count;
			port1.outb(0x00);
			curr_count = port2.inb();
			curr_count |= port2.inb() << 8;
			delta = curr_count - prev_count;

			// Comment from the Linux source code:

			// This limit for delta seems arbitrary, but it isn't, it's
			// slightly above the level of error a buggy Mercury/Neptune
			// chipset timer can cause.

			asm volatile("pause\n\t");
		} while (delta < 300);
	}
}

struct MyPixel
{
	uint8_t r;
	uint8_t g;
	uint8_t b;
	uint8_t a;
} __attribute__((packed));

static void halt()
{
	//EarlyIO::print("ERROR\n");
	for(;;) {
		asm volatile("cli\n\t hlt\n\t":::"memory");
	}
}

static uint8_t* grayScaleFromPNG(uintptr_t start, uintptr_t length)
{
	//EarlyIO::print("png start: 0x");
	//EarlyIO::putNum(start);
	//EarlyIO::print("\n");
	//EarlyIO::print("png size: ");
	//EarlyIO::putNum(length, 10);
	//EarlyIO::print("\n");
	upng_t *png = upng_new_from_bytes((unsigned char*)start, length);
	//EarlyIO::print("png obj: 0x");
	//EarlyIO::putNum((uintptr_t)png);
	//EarlyIO::print("\n");

	if(png == 0) {
		halt();
	}

	uintptr_t ret = upng_decode(png);
	//EarlyIO::print("upng_decode: ");
	//EarlyIO::putNum(ret, 10);
	//EarlyIO::print("\n");
	if(ret != UPNG_EOK) {
		halt();
	}

	uint8_t *mainPNG = (uint8_t*)upng_get_buffer(png);
	//EarlyIO::print("main buffer: 0x");
	//EarlyIO::putNum((uintptr_t)mainPNG);
	//EarlyIO::print("\n");
	//EarlyIO::print("png raw data:\n");
	if(mainPNG == 0) {
		halt();
	}

	return mainPNG;
}

static const uintptr_t width = 1024;
static const uintptr_t height = 768;

static MyPixel* toPixels(uint8_t *gray, uintptr_t w, uintptr_t h, uintptr_t transp, uintptr_t smoothTrans=0xffff)
{

	uintptr_t scaledHeight = 768;
	uintptr_t scaledWidth = (scaledHeight * w) / h ;
	//EarlyIO::print("scaled width: ");
	//EarlyIO::putNum(scaledWidth, 10);
	//EarlyIO::print("\n");


	uintptr_t offset = (width - scaledWidth) / 2;

	MyPixel *mainPic = (MyPixel*)malloc(width*height*4);

	// 240 x 320 to  576x768
	for(uint32_t y = 0; y != height; ++y) {
		for(uint32_t x = 0; x != width; ++x) {
			uint32_t idx = y * width + x;
			if(x > offset && x < offset + scaledWidth) {
				uint8_t value = interp(gray, x-offset, y, w, h, scaledWidth, height);
				mainPic[idx].r = value;
				mainPic[idx].g = value;
				mainPic[idx].b = value;
				if(value > smoothTrans) {
					mainPic[idx].a = ~value;
				}
				else {

				if(value == transp) {
					mainPic[idx].a = 0x0;
				}
				else {
					mainPic[idx].a = 0xff;
				}
				}
			}
			else {
				mainPic[idx].r = 0x16;
				mainPic[idx].g = 0x16;
				mainPic[idx].b = 0x18;
				mainPic[idx].a = 0xff;
			}
		}
	}
	return mainPic;
}

extern "C" void main()
{
	//EarlyIO::init();
	//EarlyIO::print("booting\n");
	const uintptr_t imgBufSize = width * height * 4; // RGBA

	char *buffer_1 = (char*)malloc(imgBufSize);
	char *buffer_2 = (char*)malloc(imgBufSize);

	VESAGraphics vesa(buffer_1, buffer_2);
    vesa.init();

    VBEModeData_t* new_mode = vesa.find_mode(width, height, 24);
    if (new_mode != 0) {
        vesa.set_mode(new_mode);
    }
	else {
		halt();
	}

	uintptr_t glassSize = 1761;
	uintptr_t dealSize = 1262;

	uintptr_t start = (uintptr_t)(&startup);
	uintptr_t end = ((uintptr_t)(&___IMG_END___)) + 31546;

	uintptr_t dealStart = end - dealSize;
	uintptr_t glassStart = dealStart - glassSize;

	uintptr_t meStart = start;
	uintptr_t meSize = glassStart - start;

	uint8_t *meGray = grayScaleFromPNG(meStart, meSize);
	//uint8_t *meGray = grayScaleFromPNG(glassStart, glassSize);
	uint8_t *glassGray = grayScaleFromPNG(glassStart, glassSize);
	uint8_t *dealGray = grayScaleFromPNG(dealStart, dealSize);

	MyPixel *me = toPixels(meGray, 240, 320, ~((uintptr_t)0));
	MyPixel *glass = toPixels(glassGray, 240, 320, 0xff, 0x75);
	MyPixel *deal = toPixels(dealGray, 240, 320, 0xff);

	for(int x = 350; x >= 0; x-=2) {
	//for(;;) {
		vesa.clear_screen();

		vesa.print_sprite_alpha(Point(0, 0), width, height, (const SpritePixel*)me);
		vesa.print_sprite_alpha(Point(0, 0), width, height - x, (const SpritePixel*)glass + 1024 * x);

		vesa.switch_buffers();
		vesa.VESAGraphics::scanout_frontbuffer();
		pitDelay(1);
	}

	vesa.clear_screen();
	vesa.print_sprite_alpha(Point(0, 0), width, height, (const SpritePixel*)me);
	vesa.print_sprite_alpha(Point(0, 0), width, height, (const SpritePixel*)glass);
	vesa.print_sprite_alpha(Point(0, 0), width, height, (const SpritePixel*)deal);
	vesa.switch_buffers();
	vesa.VESAGraphics::scanout_frontbuffer();

	for(;;) {
		asm volatile("cli\n\t hlt\n\t":::"memory");
	}
}

