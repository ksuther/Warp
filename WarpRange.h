//
//  WarpRange.h
//  Warp
//
//  Created by Kent Sutherland on 1/1/08.
//  Copyright 2007-2009 Kent Sutherland. All rights reserved.
//

typedef struct _WarpRange {
    CGFloat location;
    CGFloat length;
} WarpRange;

NS_INLINE WarpRange WarpMakeRange(CGFloat loc, CGFloat len) {
    WarpRange r;
    r.location = loc;
    r.length = len;
    return r;
}

NS_INLINE CGFloat WarpMaxRange(WarpRange range) {
    return (range.location + range.length);
}

NS_INLINE BOOL WarpLocationInRange(CGFloat loc, WarpRange range) {
	return (loc > range.location && loc < range.location + range.length);
    //return (loc - range.location < range.length);
}

NS_INLINE BOOL WarpEqualRanges(WarpRange range1, WarpRange range2) {
    return (range1.location == range2.location && range1.length == range2.length);
}