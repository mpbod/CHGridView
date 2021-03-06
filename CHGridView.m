//
//  CHGridView.m
//
//  RELEASED UNDER THE MIT LICENSE
//
//  Created by Cameron Kenly Hunt on 2/18/10.
//  Copyright 2010 Cameron Kenley Hunt All rights reserved.
//  http://cameron.io/project/chgridview
//

#import "CHGridView.h"
#import "CHGridLayoutTile.h"

@interface CHGridView()
@property (nonatomic, assign) CHGridIndexPath selectedIndexPath;
- (void)loadVisibleSectionTitlesForSectionRange:(CHSectionRange)range;
- (void)loadVisibleTileForIndexPath:(CHGridIndexPath)indexPath withRect:(CGRect)r;
- (void)reuseHiddenTiles;
- (void)removeSectionTitleNotInRange:(CHSectionRange)range;
- (void)removeAllSubviews;
- (NSMutableArray *)tilesForSection:(int)section;
- (NSMutableArray *)tilesFromIndex:(int)startIndex toIndex:(int)endIndex inSection:(int)section;
- (CHSectionHeaderView *)sectionHeaderViewForSection:(int)section;
- (void)calculateSectionTitleOffset;
@end

@implementation CHGridView
@synthesize dataSource, centerTilesInGrid, allowsSelection, padding, preLoadMultiplier, rowHeight, perLine, sectionTitleHeight, selectedIndexPath;
@dynamic gridHeaderView, gridFooterView;

- (void)commonSetup{
    if(visibleTiles == nil)
        visibleTiles = [[NSMutableArray alloc] init];

    if(visibleSectionHeaders == nil)
        visibleSectionHeaders = [[NSMutableArray alloc] init];

    if(reusableTiles == nil)
        reusableTiles = [[NSMutableArray alloc] init];

    if(layout == nil)
        layout = [[CHGridLayout alloc] init];

    if(sectionCounts == nil)
        sectionCounts = [[NSMutableArray alloc] init];

    sections = 0;

    allowsSelection = YES;
    centerTilesInGrid = NO;
    padding = CGSizeMake(10.0f, 10.0f);
    rowHeight = 100.0f;
    perLine = 5;
    sectionTitleHeight = 25.0f;
    selectedIndexPath = CHGridIndexPathMake(0, -1);

    preLoadMultiplier = 6.0f;

    [self setBackgroundColor:[UIColor whiteColor]];

    tilesView = [[UIView alloc] initWithFrame:CGRectZero];
    [self addSubview:tilesView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reuseHiddenTiles) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (id)init{
    if ((self = [super init])){
        [self commonSetup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    if ((self = [super initWithCoder:aDecoder])){
        [self commonSetup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame{
    if ((self = [super initWithFrame:frame])){
        [self commonSetup];
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

    [tilesView release];
	[sectionCounts release];
	[layout release];
	[reusableTiles release];
	[visibleSectionHeaders release];
	[visibleTiles release];
    [gridHeaderView release];
    [gridFooterView release];
    [super dealloc];
}

#pragma mark loading methods

- (void)loadVisibleSectionTitlesForSectionRange:(CHSectionRange)range{
	CGRect b = self.bounds;

	int i;
	for (i = range.start; i <= range.end; i++) {
		BOOL found = NO;
		
		for(CHSectionHeaderView *header in visibleSectionHeaders){
			if(header.section == i) found = YES;
		}
		
		if(!found){
			CGFloat yCoordinate = [layout yCoordinateForTitleOfSection:i];
			
			CHSectionHeaderView *sectionHeader = nil;

			if([[self delegate] respondsToSelector:@selector(headerViewForSection:inGridView:)]){
				sectionHeader = [[[self delegate] headerViewForSection:i inGridView:self] retain];
				[sectionHeader setFrame:CGRectMake(b.origin.x, yCoordinate, b.size.width, sectionTitleHeight)];
			}else{
				sectionHeader = [[CHSectionHeaderView alloc] initWithFrame:CGRectMake(b.origin.x, yCoordinate, b.size.width, sectionTitleHeight)];
				if([dataSource respondsToSelector:@selector(titleForHeaderOfSection:inGridView:)])
				{
					[sectionHeader setTitle:[dataSource titleForHeaderOfSection:i inGridView:self]];
				}
				else if(sections == 1)
				{
					[sectionHeader release];
					[layout setSectionTitleHeight:0.0f];
					continue;
				}
			}
			
			[sectionHeader setYCoordinate:yCoordinate];
			[sectionHeader setSection:i];
			[sectionHeader setAutoresizingMask:(UIViewAutoresizingFlexibleWidth)];
			
			if(self.dragging || self.decelerating)
				[tilesView insertSubview:sectionHeader atIndex:self.subviews.count - 1];
			else
				[tilesView insertSubview:sectionHeader atIndex:self.subviews.count];
				
			[visibleSectionHeaders addObject:sectionHeader];
			[sectionHeader release];
		}
	}
	
	[self removeSectionTitleNotInRange:range];
}

- (void)loadVisibleTileForIndexPath:(CHGridIndexPath)indexPath withRect:(CGRect)r{
	for(CHTileView *tile in visibleTiles){
		CHGridIndexPath tileIndex = tile.indexPath;
		if(tileIndex.section == indexPath.section && tileIndex.tileIndex == indexPath.tileIndex){
			return;
		}
	}
	
	CHTileView *tile = [dataSource tileForIndexPath:indexPath inGridView:self];
	
	[tile setIndexPath:indexPath];
    [tile setSelected:selectedIndexPath.section == indexPath.section && selectedIndexPath.tileIndex == indexPath.tileIndex];

	if([[self delegate] respondsToSelector:@selector(sizeForTileAtIndex:inGridView:)] && centerTilesInGrid){
		CGSize size = [[self delegate] sizeForTileAtIndex:indexPath inGridView:self];
		CGRect centeredRect = [layout centerRect:CGRectMake(0.0f, 0.0f, size.width, size.height) inLargerRect:r roundUp:NO];
		centeredRect.origin.y += r.origin.y;
		centeredRect.origin.x += r.origin.x;
		[tile setFrame:centeredRect];
		[tile setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin)];
	}else{
		[tile setFrame:r];
		[tile setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth)];
	}

    if (!tile.selected)
    {
        [tile setBackgroundColor:self.backgroundColor];
    }

	[tilesView insertSubview:tile atIndex:0];
	[visibleTiles addObject:tile];
}

- (void)reuseHiddenTiles{
	NSMutableArray *toReuse = [[NSMutableArray alloc] init];
	
	CGRect b = self.bounds;
	CGFloat contentOffsetY = self.contentOffset.y;
	float pixelMargin = rowHeight * ([layout preLoadMultiplier]);
	
	CGFloat firstY = (b.size.height + contentOffsetY + pixelMargin);
	CGFloat secondY = contentOffsetY - pixelMargin;
	
	for(CHTileView *tile in visibleTiles){
		CGRect r = tile.frame;
		if(r.origin.y > firstY || r.origin.y + r.size.height < secondY){
			[toReuse addObject:tile];
			if(reusableTiles.count < (uint)maxReusable) [reusableTiles addObject:tile];
		}
	}
	
	[visibleTiles removeObjectsInArray:toReuse];
	[toReuse release];
}

- (void)removeSectionTitleNotInRange:(CHSectionRange)range{
	NSMutableArray *toDelete = [NSMutableArray array];
	
	for (CHSectionHeaderView *header in visibleSectionHeaders) {
		int s = header.section;
		if(s < range.start || s > range.end){
			[toDelete addObject:header];
		}
	}
	
	[toDelete makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[visibleSectionHeaders removeObjectsInArray:toDelete];
}

- (void)reloadData{
	[self reloadDataAndLayoutUpdateNeeded:YES];
}

- (void)reloadDataAndLayoutUpdateNeeded:(BOOL)layoutNeeded{
	if(dataSource == nil) return;
	
	[self removeAllSubviews];
	[visibleTiles removeAllObjects];
	[visibleSectionHeaders removeAllObjects];
    selectedIndexPath = CHGridIndexPathMake(0, -1);

	CGRect b = [self bounds];
	
	if([dataSource respondsToSelector:@selector(numberOfSectionsInGridView:)]){
		sections = [dataSource numberOfSectionsInGridView:self];
		if(sections == 0) sections = 1;
	}else {
		sections = 1;
	}
	
	[sectionCounts removeAllObjects];
	
	if(layoutNeeded){
		[layout setGridWidth:b.size.width];
		[layout setPadding:padding];
		[layout setPerLine:perLine];
		[layout setPreLoadMultiplier:preLoadMultiplier];
		[layout setRowHeight:rowHeight];
		[layout setSectionTitleHeight:sectionTitleHeight];
	
		[layout setSections:sections];
		int i;
		for(i = 0; i < sections; i++){
			int numberInSection = [dataSource numberOfTilesInSection:i GridView:self];
			[sectionCounts addObject:[NSNumber numberWithInt:numberInSection]];
			[layout setNumberOfTiles:numberInSection ForSectionIndex:i];
		}
	
		[layout updateLayout];
	}
		
	[self setNeedsLayout];
	
	maxReusable = ceilf((self.bounds.size.height / rowHeight) * perLine) * 2;

    tilesView.frame = CGRectMake(0, (gridHeaderView ? gridHeaderView.frame.size.height : 0), b.size.width, [layout contentHeight]);

    float contentHeight = [layout contentHeight];
    if (gridHeaderView) contentHeight += gridHeaderView.frame.size.height;
    if (gridFooterView) contentHeight += gridFooterView.frame.size.height;
	if(contentHeight > b.size.height)
		[self setContentSize:CGSizeMake(b.size.width, contentHeight)];
	else
		[self setContentSize:CGSizeMake(b.size.width, b.size.height + 1.0f)];
}

- (CHTileView *)dequeueReusableTileWithIdentifier:(NSString *)identifier{
	CHTileView *foundTile = nil;
	BOOL found = NO;
	
	for(CHTileView *tile in reusableTiles){
		if(!found && [[tile reuseIdentifier] isEqualToString:identifier]){
			foundTile = tile;
			found = YES;
		}
	}
	
	if(foundTile){
		[[foundTile retain] autorelease];
		[reusableTiles removeObject:foundTile];
	}
	
	return foundTile;
}

#pragma mark view and layout methods

- (void)layoutSubviews{
	if(dataSource == nil) return;
	
	CGRect b = [self bounds];
	
	[self reuseHiddenTiles];
	
	CGFloat	contentOffsetY = self.contentOffset.y;
	CGFloat pixelMargin = rowHeight * [layout preLoadMultiplier];
	CGFloat firstY = (b.size.height + contentOffsetY + pixelMargin);
	CGFloat secondY = contentOffsetY - pixelMargin;

	if(sections != 0){
		CHSectionRange sectionRange = [layout sectionRangeForContentOffset:contentOffsetY andHeight:b.size.height];
		[self loadVisibleSectionTitlesForSectionRange:sectionRange];
		[self calculateSectionTitleOffset];
		
	}
	
	for(CHGridLayoutTile *tile in [layout justTiles]){
		CGRect r = [tile rect];
		if(r.origin.y < firstY && r.origin.y + r.size.height > secondY){
			[self loadVisibleTileForIndexPath:tile.indexPath withRect:r];
		}
	}

    if(gridHeaderView) gridHeaderView.frame = CGRectMake(0, 0, b.size.width, gridHeaderView.frame.size.height);
    if(gridFooterView) gridFooterView.frame = CGRectMake(0, self.contentSize.height - gridFooterView.frame.size.height, b.size.width, gridFooterView.frame.size.height);
	
	//if([[self delegate] respondsToSelector:@selector(visibleTilesChangedTo:)]) [[self delegate] visibleTilesChangedTo:visibleTiles.count];
}

- (void)removeAllSubviews{
	[visibleTiles makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[visibleSectionHeaders makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[reusableTiles makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

#pragma mark tiles accessor methods

- (CHTileView *)tileForIndexPath:(CHGridIndexPath)indexPath{
	CHTileView *foundTile = nil;
	
	for(CHTileView *tile in visibleTiles){
		if(tile.indexPath.section == indexPath.section && tile.indexPath.tileIndex == indexPath.tileIndex)
			foundTile = tile;
	}
	
	return foundTile;
}

- (NSMutableArray *)tilesForSection:(int)section{
	NSMutableArray *array = [NSMutableArray array];
	
	for(CHTileView *tile in visibleTiles){
		if(tile.indexPath.section == section){
			[array addObject:tile];
		}
	}
	
	if(array.count > 0) return array;
	return nil;
}

- (NSMutableArray *)tilesFromIndex:(int)startIndex toIndex:(int)endIndex inSection:(int)section{
	NSMutableArray *array = [NSMutableArray array];
	
	for(CHTileView *tile in visibleTiles){
		if(tile.indexPath.section == section && tile.indexPath.tileIndex >= startIndex && tile.indexPath.tileIndex <= endIndex){
			[array addObject:tile];
		}
	}
	
	if(array.count > 0) return array;
	return nil;
}

#pragma mark section title accessor methods

- (CHSectionHeaderView *)sectionHeaderViewForSection:(int)section{
	CHSectionHeaderView *headerView = nil;
	
	for(CHSectionHeaderView *header in visibleSectionHeaders){
		if([header section] == section) headerView = header;
	}
	
	return headerView;
}

#pragma mark indexPath accessor methods

- (CHGridIndexPath)indexPathForPoint:(CGPoint)point{
	return CHGridIndexPathMake(0, 0);
}

#pragma mark tile scrolling methods

- (void)scrollToTileAtIndexPath:(CHGridIndexPath)indexPath animated:(BOOL)animated{
	CGRect r = [layout tileFrameForIndexPath:indexPath];
	[self scrollRectToVisible:r animated:animated];
}

#pragma mark selection methods

- (void)selectTileAtIndexPath:(CHGridIndexPath)indexPath animated:(BOOL)animated{
    if(selectedIndexPath.tileIndex != -1)
        [self deselectTileAtIndexPath:selectedIndexPath];

    [self scrollToTileAtIndexPath:indexPath animated:animated];
    self.selectedIndexPath = indexPath;
    [self setNeedsLayout];
}

- (void)deselectTileAtIndexPath:(CHGridIndexPath)indexPath{
	for(CHTileView *tile in visibleTiles){
		if(tile.indexPath.section == indexPath.section && tile.indexPath.tileIndex == indexPath.tileIndex){
			[tile setSelected:NO];
			self.selectedIndexPath = CHGridIndexPathMake(0, -1);
		}
	}
}

- (void)deselectSelectedTile{
	if(selectedIndexPath.tileIndex != -1){
		[self deselectTileAtIndexPath:selectedIndexPath];
	}
}

#pragma mark property setters and getters

- (id<CHGridViewDelegate>)delegate {
	return (id<CHGridViewDelegate>)[super delegate];
}

- (void)setDelegate:(id<UIScrollViewDelegate,CHGridViewDelegate>)d{
	[super setDelegate:d];
}

- (void)setDataSource:(id<CHGridViewDataSource>)d{
	dataSource = d;
}

- (void)setCenterTilesInGrid:(BOOL)b{
	centerTilesInGrid = b;
	[self setNeedsLayout];
}

- (void)setAllowsSelection:(BOOL)allows{
	allowsSelection = allows;
}

- (UIView *)gridHeaderView{
    return [[gridHeaderView retain] autorelease];
}

- (void)setGridHeaderView:(UIView *)view{
    [gridHeaderView removeFromSuperview];
    gridHeaderView = [view retain];
    [self insertSubview:view atIndex:0];
    [self setNeedsLayout];
}

- (UIView *)gridFooterView{
    return [[gridFooterView retain] autorelease];
}

- (void)setGridFooterView:(UIView *)view{
    [gridFooterView removeFromSuperview];
    gridFooterView = [view retain];
    [self addSubview:view];
    [self setNeedsLayout];
}

#pragma mark touch methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
	[super touchesBegan:touches withEvent:event];
	UITouch *touch = [[event allTouches] anyObject];
	CGPoint location = [touch locationInView:self];

	UIView *view = [self hitTest:location withEvent:event];
	
	if([view isKindOfClass:[CHTileView class]] && allowsSelection){
		if(selectedIndexPath.tileIndex != -1)
			[self deselectTileAtIndexPath:selectedIndexPath];


		self.selectedIndexPath = ((CHTileView *)view).indexPath;
		[(CHTileView *)view setSelected:YES];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
	[super touchesMoved:touches withEvent:event];

	if(self.dragging || self.tracking || (self.decelerating && allowsSelection)){
		if(selectedIndexPath.tileIndex != -1){
			[[self tileForIndexPath:selectedIndexPath] setSelected:NO];
			self.selectedIndexPath = CHGridIndexPathMake(0, -1);
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
	[super touchesEnded:touches withEvent:event];
	UITouch *touch = [[event allTouches] anyObject];
	CGPoint location = [touch locationInView:self];
	
	UIView *view = [self hitTest:location withEvent:event];

	if([view isKindOfClass:[CHTileView class]] && allowsSelection){
        CHGridIndexPath indexPath = ((CHTileView *)view).indexPath;
        if(selectedIndexPath.section == indexPath.section && selectedIndexPath.tileIndex == indexPath.tileIndex && allowsSelection){
            if([[self delegate] respondsToSelector:@selector(selectedTileAtIndexPath:inGridView:)])
                [[self delegate] selectedTileAtIndexPath:indexPath inGridView:self];
        }
    }
}

#pragma mark section title view offset

- (void)calculateSectionTitleOffset{
	float offset = self.contentOffset.y;
	
	for(CHSectionHeaderView *header in visibleSectionHeaders){
		CGRect f = [header frame];
		float sectionY = [header yCoordinate];
		
		if(sectionY <= offset && offset > 0.0f){
			f.origin.y = offset;
			if(offset <= 0.0f) f.origin.y = sectionY;
			
			CHSectionHeaderView *sectionTwo = [self sectionHeaderViewForSection:header.section + 1];
			if(sectionTwo != nil){
				CGFloat sectionTwoHeight = sectionTwo.frame.size.height;
				CGFloat	sectionTwoY = sectionTwo.yCoordinate;
				if((offset + sectionTwoHeight) >= sectionTwoY){
					f.origin.y = sectionTwoY - sectionTwoHeight;
				}
			}
		}else{
			f.origin.y = sectionY;
		}
		
		if(f.origin.y <= offset) [header setOpaque:NO];
		else [header setOpaque:YES];
		
		[header setFrame:f];
	}
}

@end
