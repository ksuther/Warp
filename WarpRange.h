/*
 * WarpRange.h
 *
 * Copyright (c) 2007-2011 Kent Sutherland
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
 * Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

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