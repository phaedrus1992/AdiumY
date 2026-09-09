//
//	NSMutableArrayAdditions.m
//	Growl
//
//	Created by Mac-arena the Bored Zo on 2005-09-12.
//  Copyright 2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "NSMutableArrayAdditions.h"
#include <objc/objc-runtime.h>

static inline NSComparisonResult compareObjectsWithSelector(id a, id b, SEL cmd);

@implementation NSMutableArray (NSMutableArrayAdditions)

- (unsigned)indexForInsortingObject:(id)obj usingSelector:(SEL)compareCmd
{
	unsigned count = [self count];
	if (!count) {
		// bail now so we can assume a non-empty array later
		return 0U;
	} else if (count == 1U) {
		// bail now so we can assume an array with more than one object later
		return compareObjectsWithSelector(obj, [self objectAtIndex:0U], compareCmd) == NSOrderedDescending;
	}

	unsigned i = count / 2U;
	NSComparisonResult initialComparison = compareObjectsWithSelector(obj, [self objectAtIndex:i], compareCmd);
	if (initialComparison == NSOrderedSame) {
		/*the object to be inserted is equal to the pivot, so we can just insert it
		 *	right here.
		 */
		return i;
	}
	signed movementDirection = initialComparison;
	i += movementDirection;

	while ((i > 0U) && (i < count) &&
		   compareObjectsWithSelector(obj, [self objectAtIndex:i], compareCmd) == initialComparison) {
		i += movementDirection;
	}

	return i;
}

@end

static inline NSComparisonResult compareObjectsWithSelector(id a, id b, SEL cmd)
{
	/* Modern SDKs declare objc_msgSend with no parameters so a caller must cast it to the
	 * actual signature before invoking it — the untyped variadic form is no longer usable
	 * directly on arm64. */
	NSComparisonResult (*comparisonSend)(id, SEL, id) = (NSComparisonResult (*)(id, SEL, id))objc_msgSend;
	return comparisonSend(a, cmd, b);
}
