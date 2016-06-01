//
//  GSBURLImage.h
//  GSBURLImage
//
//  Created by Gareth Bestor on 2/06/16.
//  Copyright © 2016 Xiphware. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GSBURLImage : UIImage
+ (instancetype)imageWithURL:(NSURL*)url;
+ (instancetype)imageWithURL:(NSURL*)url placeholder:(UIImage*)image;
- (void)onCompletionRedrawView:(UIView*)view;
@end

// Convenience methods for using GSBURLImage in a UIImageView; e.g. (UITableViewCell*)cell.imageView.URLimage = ...
@interface UIImageView (GSBURLImage)
- (void)setURLImage:(GSBURLImage*)image;
- (GSBURLImage*)URLImage;
@end
