//
//  AppDelegate.m
//  ZXingCode
//
//  Created by Dylan Xiao on 2018/10/25.
//  Copyright © 2018年 Dylan Xiao. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (weak) IBOutlet NSImageView *imageView;
@property (weak) IBOutlet NSTextField *lbl_text;
- (IBAction)Btn_Scan:(NSButton *)sender;
- (IBAction)Btn_CreateBarcode:(NSButton *)sender;
@property ZXCapture *capture;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

-(void)setupCapture
{
    self.capture = [[ZXCapture alloc]init];
    self.capture.camera = self.capture.front;
    //自动聚焦
    self.capture.focusMode =  AVCaptureFocusModeContinuousAutoFocus;
    self.capture.layer.frame = self.imageView.frame;
    
    [self.window.contentView.layer addSublayer:self.capture.layer];
    self.capture.delegate = self;
}

#pragma mark - ZXCaptureDelegate
- (void)captureResult:(ZXCapture *)capture result:(ZXResult *)result {
    if (!result) return;
    
    NSLog(@"\n%@\n",result.text);
    NSLog(@"result.format = %d",result.barcodeFormat);
    
    if (result.barcodeFormat == kBarcodeFormatQRCode){
        [self.capture stop];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setInformativeText:result.text];
        alert.messageText = @"Good";
        [alert runModal];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.capture start];
        });
    }
}

#pragma mark - ZXing 生成&解析二维码
/**
 *  根据字符串生成二维码 UIImage 对象
 *  @param str 需要生成二维码的字符串
 *  @param size 生成的大小
 *  @param format 二维码选 kBarcodeFormatQRCode
 *  @return 生成的二维码
 */
- (NSImage*)createCodeWithString:(NSString*)str
                            size:(CGSize)size
                      CodeFomart:(ZXBarcodeFormat)format
{
    ZXMultiFormatWriter *writer = [[ZXMultiFormatWriter alloc] init];
    ZXBitMatrix *result = [writer encode:str format:format width:size.width height:size.width error:nil];
    ZXImage *image = [ZXImage imageWithMatrix:result];
    NSSize imageSize = NSMakeSize(CGImageGetWidth(image.cgimage), CGImageGetHeight(image.cgimage));
    return [[NSImage alloc] initWithCGImage:image.cgimage size:imageSize];
}


-(NSImage *)createCodeWithString:(NSString *)str
                            size:(CGSize)size
                      codeFomart:(ZXBarcodeFormat)format
                       codeColor:(uint32_t)codeColor    //#FF00CC00   OX8C8C00
                 backgroundColor:(uint32_t)backgroundColor   //#FF580900
{
    ZXMultiFormatWriter *writer = [[ZXMultiFormatWriter alloc] init];
    ZXBitMatrix *result = [writer encode:str format:format width:size.width height:size.width error:nil];
    NSImage *img = [self imageWithZXBitMatrix:result codeColor:codeColor backgroundColor:backgroundColor];
    return img;
}

//3、设置二维码颜色
-(NSImage *)imageWithZXBitMatrix:(ZXBitMatrix *)result
                       codeColor:(uint32_t)codeColor
                 backgroundColor:(uint32_t)backgroundColor
{
    int width = result.width;
    int height = result.height;
    int8_t *bytes = (int8_t *)malloc(width * height * 4);
    for(int y = 0; y < height; y++) {
        for(int x = 0; x < width; x++) {
            BOOL bit = [result getX:x y:y];
            // codeColor 对应的4个byte 从高到低分别为RGBA A为透明度
            // byte数组4个字节表示一个像素信息，BGRA，前三个字节数据刚好相反
            for(int i = 0; i < 3; i++) {
                int8_t intensity = bit ? codeColor>>(8*(i+1)) : backgroundColor>>(8*(i+1));
                bytes[y * width * 4 + x * 4 + i] = intensity;
            }
            int8_t intensity = bit ? codeColor : backgroundColor;
            bytes[y * width * 4 + x * 4 + 3] = intensity;
        }
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(bytes, width, height, 8, 4 * width, colorSpace, kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
    CFRelease(colorSpace);
    CGImageRef image = CGBitmapContextCreateImage(c);
    CFRelease(c);
    free(bytes);
    NSImage *newImage = [self imageFromCGImageRef:image];
    CFRelease(image);
    return newImage;
}

#pragma mark - 系统自带创建QR二维码 & 识别
/**
 *  根据字符串生成二维码 CIImage 对象
 *  @param urlString 需要生成二维码的字符串
 *  @return 生成的二维码
 */
- (CIImage *)creatQRcodeWithUrlstring:(NSString *)urlString{
    // 1.实例化二维码滤镜
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // 2.恢复滤镜的默认属性 (因为滤镜有可能保存上一次的属性)
    [filter setDefaults];
    // 3.将字符串转换成NSdata
    NSData *data  = [urlString dataUsingEncoding:NSUTF8StringEncoding];
    // 4.通过KVO设置滤镜, 传入data, 将来滤镜就知道要通过传入的数据生成二维码
    [filter setValue:data forKey:@"inputMessage"];
    // 5.生成二维码
    CIImage *outputImage = [filter outputImage];
    return outputImage;
}


/**
 *  读取图片中的二维码
 *  @param image 图片
 *  @return 图片中的二维码数据集合 CIQRCodeFeature对象
 */
- (NSArray *)readQRCodeFromImage:(NSImage *)image{
    // 创建一个CIImage对象 [NSImage -> bitmap -> CIImage]
    NSData *tiffData = [image TIFFRepresentation];
    NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
    CIImage *ciImage = [[CIImage alloc] initWithBitmapImageRep:bitmap];
    
    CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @(YES)}]; // 软件渲染
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:context options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];// 二维码识别
    // 注意这里的CIDetectorTypeQRCode
    NSArray *features = [detector featuresInImage:ciImage];
    NSLog(@"features = %@",features); // 识别后的结果集
    for (CIQRCodeFeature *feature in features) {
        NSLog(@"msg = %@",feature.messageString); // 打印二维码中的信息
    }
    return features;
}


//将CGImageRef转换为NSImage
-(NSImage *)imageFromCGImageRef:(CGImageRef)image
{
    NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
    CGContextRef imageContext = nil;
    NSImage* newImage = nil;
    
    // Get the image dimensions.
    imageRect.size.height = CGImageGetHeight(image);
    imageRect.size.width = CGImageGetWidth(image);

    // Create a new image to receive the Quartz image data.
    newImage = [[NSImage alloc] initWithSize:imageRect.size];
    [newImage lockFocus];
    
    // Get the Quartz context and draw.
    imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextDrawImage(imageContext, *(CGRect*)&imageRect, image);
    [newImage unlockFocus];

    return newImage;
}

//将NSImage 转换为CGImageRef
- (CGImageRef)nsImageToCGImageRef:(NSImage*)image;
{
    NSData * imageData = [image TIFFRepresentation];
    CGImageRef imageRef=nil;
    if(imageData)
    {
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData,  NULL);
        imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    }
    
    return imageRef;
}


- (IBAction)Btn_Scan:(NSButton *)sender {
    if ([sender.title isEqualToString:@"Scan"]) {
        [self setupCapture];
        sender.title = @"Stop";
    }else
    {
        [self.capture stop];
        sender.title =@"Scan";
    }
}

- (IBAction)Btn_CreateBarcode:(NSButton *)sender {
    NSString *text = _lbl_text.stringValue;
   // NSImage *image = [self createCodeWithString:text size:CGSizeMake(300, 300) CodeFomart:kBarcodeFormatQRCode];
    
    NSImage *img2= [self createCodeWithString:text
                                         size:CGSizeMake(300, 300)
                                   codeFomart:kBarcodeFormatQRCode
                                    codeColor:0x00FFFFFF
                              backgroundColor:0XFF5809FA];
    
    self.imageView.image =img2;
}
@end
