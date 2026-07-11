//
//  NSString-FBAdditions.m
//  Adium
//
//  Implementation of base writing direction detection via FriBidi.
//

#import "NSString-FBAdditions.h"
#include <fribidi/fribidi.h>

@implementation NSString (FBAdditions)

- (NSWritingDirection)baseWritingDirection
{
	if ([self length] == 0) {
		return NSWritingDirectionNatural;
	}

	// Convert the receiver to UTF-32-LE for FriBidi's FriBidiChar array.
	// -dataUsingEncoding: on NSString does not insert a BOM, so the first
	// character is the first actual codepoint.
	NSData *utf32 = [self dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
	const FriBidiChar *chars = (const FriBidiChar *)[utf32 bytes];
	FriBidiStrIndex len = (FriBidiStrIndex)([utf32 length] / sizeof(FriBidiChar));

	if (len == 0) {
		return NSWritingDirectionNatural;
	}

	// Allocate bidi type array for the string
	FriBidiCharType *types = malloc((size_t)len * sizeof(FriBidiCharType));
	if (types == NULL) {
		return NSWritingDirectionNatural;
	}
	fribidi_get_bidi_types(chars, len, types);

	FriBidiParType direction = fribidi_get_par_direction(types, len);
	free(types);

	switch (direction) {
	case FRIBIDI_PAR_RTL:
	case FRIBIDI_PAR_WRTL:
		return NSWritingDirectionRightToLeft;

	case FRIBIDI_PAR_LTR:
	case FRIBIDI_PAR_WLTR:
		return NSWritingDirectionLeftToRight;

	case FRIBIDI_PAR_ON:
	default:
		return NSWritingDirectionNatural;
	}
}

@end
