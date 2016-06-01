//
//  GSBURLImage.m
//  GSBURLImage
//
//  Created by Gareth Bestor on 2/06/16.
//  Copyright © 2016 Xiphware. All rights reserved.
//

#import "GSBURLImage.h"
#import <ImageIO/ImageIO.h>

typedef enum {png, jpg} ImageType;

@interface GSBURLImage()
@property NSURL *url;
@property ImageType imageType;
@property CGImageRef cachedImage;
@property UIImage *placeholder;
@property NSMutableArray *views; // list of views to refresh once image has finished loading
@end

@implementation GSBURLImage

+ (instancetype)imageWithURL:(NSURL*)url
{
    ImageType type;
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"png"]) {
        type = png;
    } else if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) {
        type = jpg;
    } else {
        return nil; // CGDataProviderRef can only handle PNG or JPEG images
    }
    
    GSBURLImage *image = super.new;
    if (image) {
        image->_imageType = type;
        image->_url = url;
        image->_views = NSMutableArray.new;
    }
    return image;
}

+ (instancetype)imageWithURL:(NSURL*)url placeholder:(UIImage*)placeholder
{
    GSBURLImage *image = [self imageWithURL:url];
    if (image) {
        image->_placeholder = placeholder;
    }
    return image;
}

// Override image getter to fetch image on demand; that is, ony when CGImage data is actually queried
- (CGImageRef)CGImage
{
    @synchronized(self) { // only want one thread to ever fetch the image
        if (!_cachedImage) {
            if (_placeholder) {
                _cachedImage = _placeholder.CGImage;
            } else {
                // otherwise create 1x1 pixel placeholder image
                UInt8 pixel = 0xFF; // single monochrome white pixel
                CFDataRef data = CFDataCreate(NULL, &pixel, sizeof(UInt8));
                CGDataProviderRef __block dataProvider = CGDataProviderCreateWithCFData(data);
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
                _cachedImage = CGImageCreate(1, 1, 8, 8, 1, colorSpace, kCGBitmapByteOrderDefault, dataProvider, NULL, false, kCGRenderingIntentDefault);
                CGColorSpaceRelease(colorSpace);
                CGDataProviderRelease(dataProvider);
                CFRelease(data);
            }
            
            // Download image in background using CGDataProviderCreateWithURL()
            [NSOperationQueue.new addOperation:[NSBlockOperation blockOperationWithBlock:^{
                CGDataProviderRef dataProvider = CGDataProviderCreateWithURL((__bridge CFURLRef)_url); // download image data
                CGImageRef old = _cachedImage; // do this because CGImageRelease(_cachedImage) could temporarily set cachedImage=nil
                if (_imageType == png) {
                    _cachedImage = CGImageCreateWithPNGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);
                } else {
                    _cachedImage = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);
                }
                CGDataProviderRelease(dataProvider);
                if (!_placeholder) CGImageRelease(old); // can now safely free 1x1 placeholder CGImage
                
                // Refresh any views using this image
                for (UIView *view in _views) {
                    if (!view.window) continue; // do nothing if view isnt currently visible
                    
                    [view performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
                    
                    // CRITICAL: check for UITableViewCell superview because this requires re-layout to make new image appear!
                    UIView *cell = view;
                    do {
                        if ([cell isKindOfClass:UITableViewCell.class]) {
                            [cell performSelectorOnMainThread:@selector(setNeedsLayout) withObject:nil waitUntilDone:NO];
                            break;
                        }
                        cell = cell.superview; // otherwise keep looking up view hierarchy
                    } while (cell);
                }
            }]];
        }
    }
    return _cachedImage;
}

- (CGSize)size
{
    CGImageRef cgimage = self.CGImage; // note: querying image size will cause the CGImage to be downloaded if its not already
    return CGSizeMake((CGFloat)CGImageGetWidth(cgimage),(CGFloat)CGImageGetHeight(cgimage));
}

- (void)dealloc
{
    if (_cachedImage && !_placeholder) CGImageRelease(_cachedImage);
    _cachedImage = nil;
}

- (void)onCompletionRedrawView:(UIView*)view
{
    [_views addObject:view];
}

@end

@implementation UIImageView (GSBURLImage)

- (void)setURLImage:(GSBURLImage*)image
{
    self.image = image;
    [image onCompletionRedrawView:self];
}

- (GSBURLImage*)URLImage
{
    return ([self.image isKindOfClass:GSBURLImage.class])? (GSBURLImage*)(self.image) : nil;
}

@end
