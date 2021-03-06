//
//  CHTileView.h
//
//  RELEASED UNDER THE MIT LICENSE
//
//  Created by Cameron Kenly Hunt on 2/18/10.
//  Copyright 2010 Cameron Kenley Hunt All rights reserved.
//  http://cameron.io/project/chgridview
//

#import <UIKit/UIKit.h>

struct CHGridIndexPath {
	int section;
	int tileIndex;
};
typedef struct CHGridIndexPath CHGridIndexPath;

static inline CHGridIndexPath CHGridIndexPathMake(int section, int tileIndex){
	CHGridIndexPath indexPath; indexPath.section = section; indexPath.tileIndex = tileIndex; return indexPath;
}

@interface CHTileView : UIView {
	NSString			*reuseIdentifier;
	CHGridIndexPath		indexPath;
	CGSize				padding;
	
	BOOL				selected;
	BOOL				highlighted;
	
	UIColor				*contentBackgroundColor;
	
	CGSize				shadowOffset;
	UIColor				*shadowColor;
	CGFloat				shadowBlur;
}

@property (nonatomic) CHGridIndexPath				indexPath;
@property (nonatomic, copy) NSString                *reuseIdentifier;

@property (nonatomic) BOOL							selected;
@property (nonatomic) BOOL							highlighted;

@property (nonatomic, retain) UIColor				*contentBackgroundColor;

@property (nonatomic) CGSize						shadowOffset;
@property (nonatomic, retain) UIColor				*shadowColor;
@property (nonatomic) CGFloat						shadowBlur;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseId;

// sub classes must implement drawContentRect:
- (void)drawContentRect:(CGRect)rect;
- (void)unselect;

@end
