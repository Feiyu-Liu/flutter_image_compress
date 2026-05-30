//
// Created by cjl on 2018/9/8.
//

#import "CompressHandler.h"
#import "UIImage+scale.h"
#import "UIImage+WebP.h"
#import "ImageCompressPlugin.h"
#import <SDWebImageWebPCoder/SDImageWebPCoder.h>
#import <ImageIO/ImageIO.h>

static NSString *const FICCompressErrorDomain = @"FlutterImageCompressErrorDomain";

@implementation CompressHandler {

}

+ (NSData *)compressWithData:(NSData *)data minWidth:(int)minWidth minHeight:(int)minHeight quality:(int)quality
                      rotate:(int)rotate format:(int)format {
    return [self compressWithData:data minWidth:minWidth minHeight:minHeight quality:quality rotate:rotate format:format error:nil];
}

+ (NSData *)compressWithData:(NSData *)data minWidth:(int)minWidth minHeight:(int)minHeight quality:(int)quality
                      rotate:(int)rotate format:(int)format error:(NSError **)error {
    UIImage *img = [self isWebP:data] ? [UIImage sd_imageWithWebPData:data] : [[UIImage alloc] initWithData:data];
    return [CompressHandler compressWithUIImage:img minWidth:minWidth minHeight:minHeight quality:quality rotate:rotate format:format error:error];
}

+ (NSData *)compressWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight quality:(int)quality
                         rotate:(int)rotate format:(int)format {
    return [self compressWithUIImage:image minWidth:minWidth minHeight:minHeight quality:quality rotate:rotate format:format error:nil];
}

+ (NSData *)compressWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight quality:(int)quality
                         rotate:(int)rotate format:(int)format error:(NSError **)error {
    if (image == nil) {
        if (error != nil) {
            *error = [NSError errorWithDomain:FICCompressErrorDomain
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unable to decode source image."}];
        }
        return nil;
    }

    if([ImageCompressPlugin showLog]){
        NSLog(@"width = %.0f",[image size].width);
        NSLog(@"height = %.0f",[image size].height);
        NSLog(@"minWidth = %d",minWidth);
        NSLog(@"minHeight = %d",minHeight);
        NSLog(@"format = %d", format);
    }

    image = [image scaleWithMinWidth:minWidth minHeight:minHeight];
    if(rotate % 360 != 0){
        image = [image rotate: rotate];
    }
    NSData *resultData = [self compressDataWithImage:image quality:quality format:format error:error];

    return resultData;
}


+ (NSData *)compressDataWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight
                            quality:(int)quality rotate:(int)rotate format:(int)format {
    return [self compressDataWithUIImage:image minWidth:minWidth minHeight:minHeight quality:quality rotate:rotate format:format error:nil];
}

+ (NSData *)compressDataWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight
                            quality:(int)quality rotate:(int)rotate format:(int)format error:(NSError **)error {
    if (image == nil) {
        if (error != nil) {
            *error = [NSError errorWithDomain:FICCompressErrorDomain
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unable to decode source image."}];
        }
        return nil;
    }

    image = [image scaleWithMinWidth:minWidth minHeight:minHeight];
    if(rotate % 360 != 0){
        image = [image rotate: rotate];
    }
    return [self compressDataWithImage:image quality:quality format:format error:error];
}

+ (NSData *)compressDataWithImage:(UIImage *)image quality:(float)quality format:(int)format error:(NSError **)error  {
    NSData *data;
    if (format == 2) { // heic
        if (@available(iOS 11.0, *)) {
            NSMutableData *heicData = [NSMutableData data];
            NSString *heicType = @"public.heic";
            CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)heicData,
                                                                                 (__bridge CFStringRef)heicType,
                                                                                 1,
                                                                                 nil);
            if (destination == nil) {
                if (error != nil) {
                    *error = [NSError errorWithDomain:FICCompressErrorDomain
                                                 code:1002
                                             userInfo:@{NSLocalizedDescriptionKey: @"Unable to create HEIC image destination."}];
                }
                return nil;
            }

            NSDictionary *options = @{
                (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(quality / 100)
            };
            CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)options);
            BOOL success = CGImageDestinationFinalize(destination);
            CFRelease(destination);

            if (!success || heicData.length == 0) {
                if (error != nil) {
                    *error = [NSError errorWithDomain:FICCompressErrorDomain
                                                 code:1003
                                             userInfo:@{NSLocalizedDescriptionKey: @"Unable to encode HEIC image data."}];
                }
                return nil;
            }

            data = heicData;
        } else {
            if (error != nil) {
                *error = [NSError errorWithDomain:FICCompressErrorDomain
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: @"HEIC compression requires iOS 11.0 or later."}];
            }
            data = nil;
        }
    } else if(format == 3){ // webp
        SDImageCoderOptions *option = @{SDImageCoderEncodeCompressionQuality: @(quality / 100)};
        data = [[SDImageWebPCoder sharedCoder]encodedDataWithImage:image format:SDImageFormatWebP options:option];
    } else if(format == 1){ // png
        data = UIImagePNGRepresentation(image);
    }else { // 0 or other is jpeg
        data = UIImageJPEGRepresentation(image, (CGFloat) quality / 100);
    }

    if (data == nil && error != nil) {
        *error = [NSError errorWithDomain:FICCompressErrorDomain
                                     code:1005
                                 userInfo:@{NSLocalizedDescriptionKey: @"Image compression produced no data."}];
    }

    return data;
}

+ (BOOL)isWebP:(NSData *)data {
    if (data.length < 12) return false;

    NSData *riff = [data subdataWithRange:NSMakeRange(8, 4)];
    NSString* format = [[NSString alloc] initWithData:riff encoding:(NSASCIIStringEncoding)];

    return [format isEqualToString:@"WEBP"];
}

@end
