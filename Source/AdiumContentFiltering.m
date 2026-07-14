/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AdiumContentFiltering.h"

@interface AdiumContentFiltering ()
- (void)_registerContentFilter:(id)inFilter filterArray:(NSMutableArray *)inFilterArray;
@end

@implementation AdiumContentFiltering

/*!
 * @brief Init
 */
- (id)init
{
	if ((self =
}
else
{
	performedFilters = [NSMutableArray array];
}

for (id filter in inContentFilterArray) {
	// Only run the filter if there were no previously performed filters or this hasn't been previously done
	if (!filtersToSkip || ![filtersToSkip containsObject:filter]) {
		if ([filter conformsToProtocol:@protocol(AIDelayedContentFilter)]) {
			beganDelayedFiltering = [(id<AIDelayedContentFilter>)filter delayedFilterAttributedString:*attributedString
																							  context:filterContext
																							 uniqueID:uniqueID];
		} else {
			@try {
				*attributedString = [(id<AIContentFilter>)filter filterAttributedString:*attributedString
																				context:filterContext];
			} @catch (NSException *exception) {
				AILogWithSignature(@"Caught exception in content %@: %@", filter, exception);
			}
		}
	}

	// Note that we've now completed this filter
	[performedFilters addObject:filter];
	if (beganDelayedFiltering)
		break;
}

if (finishedFilters)
	*finishedFilters = performedFilters;

return beganDelayedFiltering;
}

/*!
 * @brief Filter an attributed string immediately
 *
 * This does not perform delayed filters (it passes the delayed content filters as filtersToSkip).
 *
 * @param attributedString NSAttributedString to filter
 * @param type Type of the filter
 * @param direction Direction of the filter
 * @param filterContext A object, such as an AIListContact or an AIAccount, used as context by filters
 * @result The filtered attributed string, which may be the same as attributedString
 */
- (NSAttributedString *)filterAttributedString:(NSAttributedString *)attributedString
							   usingFilterType:(AIFilterType)type
									 direction:(AIFilterDirection)direction
									   context:(id)filterContext
{
	[self _filterAttributedString:&attributedString
					contentFilter:contentFilter[type][direction]
					filterContext:filterContext
			uniqueDelayedFilterID:0
					filtersToSkip:delayedContentFilters[type][direction]
				  finishedFilters:NULL];

	return attributedString;
}

/*!
 * @brief Filter an attributed string, notifying a target when complete
 *
 * This performs delayed filters, which means there may be a non-blocking delay before the filtered attributed string
 * is returned.
 *
 * @param attributedString NSAttributedString to filter
 * @param type Type of the filter
 * @param direction Direction of the filter
 * @param filterContext A object, such as an AIListContact or an AIAccount, used as context by filters
 * @param target Target to notify when filtering is complete
 * @param selector Selector to call on target.  It should take 2 arguments; the first will be the filtered
 * attributedString; the second is the passed context.
 * @param context Context passed back to target via selector when filtering is complete
 * @result The filtered attributed string, which may be the same as attributedString
 */
- (void)filterAttributedString:(NSAttributedString *)attributedString
			   usingFilterType:(AIFilterType)type
					 direction:(AIFilterDirection)direction
				 filterContext:(id)filterContext
			   notifyingTarget:(id)target
					  selector:(SEL)selector
					   context:(id)context
{
	NSParameterAssert(type >= 0 && type < FILTER_TYPE_COUNT);
	NSParameterAssert(direction >= 0 && direction < FILTER_DIRECTION_COUNT);

	BOOL shouldDelay = NO;
	NSInvocation *invocation;

	// Set up the invocation
	invocation = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:selector]];
	[invocation setSelector:selector];
	[invocation setTarget:target];
	[invocation setArgument:&context
					atIndex:3]; // context, the second argument after the two hidden arguments of every NSInvocation

	if (attributedString) {
		static unsigned long long uniqueDelayedFilterID = 0;
		NSArray *performedFilters = nil;

		// Perform the filters
		shouldDelay = [self _filterAttributedString:&attributedString
									  contentFilter:contentFilter[type][direction]
									  filterContext:filterContext
							  uniqueDelayedFilterID:uniqueDelayedFilterID
									  filtersToSkip:nil
									finishedFilters:&performedFilters];

		// If we should delay (a delayed filter is doing its thing), store what we need to finish later
		if (shouldDelay) {
			NSMutableDictionary *trackingDict;

			// NSInvocation does not retain its arguments by default; if we're caching the invocation, we must tell it
			// to.
			[invocation retainArguments];

			trackingDict = [NSMutableDictionary
				dictionaryWithObjectsAndKeys:invocation, @"Invocation", contentFilter[type][direction],
											 @"Delayed Content Filter", filterContext, @"Filter Context", nil];

			if (performedFilters) {
				[trackingDict setObject:performedFilters forKey:@"Performed Filters"];
			}

			// Track this so we can invoke with the filtered product later
			[delayedFilteringDict setObject:trackingDict
									 forKey:[NSNumber numberWithUnsignedLongLong:uniqueDelayedFilterID]];
		}

		// Increment our delayed filter ID
		uniqueDelayedFilterID++;
	}

	// If we didn't delay, invoke immediately
	if (!shouldDelay) {
		// Put that attributed string into the invocation as the first argument after the two hidden arguments of every
		// NSInvocation
		[invocation setArgument:&attributedString atIndex:2];

		// Send the filtered attributedString back via the invocation
		[invocation invoke];
	}
}

/*!
 * @brief A delayed filter finished filtering
 *
 * After this filter finishes, run it through the delayed filter system again
 * to hit the next delayed string, if necessary.
 *
 * If no more delayed filtering is needed, look up the invocation and pass the
 * now-finished string to the appropriate target.
 */
- (void)delayedFilterDidFinish:(NSAttributedString *)attributedString uniqueID:(unsigned long long)uniqueID
{
	NSNumber *uniqueIDNumber;
	NSMutableDictionary *infoDict;
	NSArray *performedFilters = nil;
	BOOL shouldDelay;

	uniqueIDNumber = [NSNumber numberWithUnsignedLongLong:uniqueID];
	infoDict = [delayedFilteringDict objectForKey:uniqueIDNumber];

	// Run through the filters again, skipping the ones we did previously, since a delayed filter would stop after the
	// first hit
	shouldDelay = [self _filterAttributedString:&attributedString
								  contentFilter:[infoDict objectForKey:@"Delayed Content Filter"]
								  filterContext:[infoDict objectForKey:@"Filter Context"]
						  uniqueDelayedFilterID:uniqueID
								  filtersToSkip:[infoDict objectForKey:@"Performed Filters"]
								finishedFilters:&performedFilters];

	// If we no longer need to delay, set up the invocation and invoke it
	if (!shouldDelay) {
		NSInvocation *invocation = [infoDict objectForKey:@"Invocation"];

		// Put that attributed string into the invocation as the first argument after the two hidden arguments of every
		// NSInvocation
		[invocation setArgument:&attributedString atIndex:2];

		// Send the filtered attributedString back via the invocation
		[invocation invoke];

		// No further need for the infoDict from delayedFilteringDict
		[delayedFilteringDict removeObjectForKey:uniqueIDNumber];

	} else {
		/* performedFilters may now be a different object after filters ran;
		 * update the infoDict for the next delayedFilterDidFinsh:uniqueId: call
		 */
		[infoDict setObject:performedFilters forKey:@"Performed Filters"];
	}
}

#pragma mark Filter priority sort
static NSInteger filterSort(id<AIContentFilter> filterA, id<AIContentFilter> filterB, void *context)
{
	CGFloat filterPriorityA = [filterA filterPriority];
	CGFloat filterPriorityB = [filterB filterPriority];

	if (filterPriorityA < filterPriorityB)
		return NSOrderedAscending;
	else if (filterPriorityA > filterPriorityB)
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}

/*!
 * @brief Add a content filter to the specified array
 *
 * Adds, then sorts by priority
 */
- (void)_registerContentFilter:(id)inFilter filterArray:(NSMutableArray *)inFilterArray
{
	NSParameterAssert(inFilter != nil);

	[inFilterArray addObject:inFilter];
	[inFilterArray sortUsingFunction:filterSort context:nil];
}

@end
