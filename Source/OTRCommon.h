/* libotr headers.
 *
 * Order matters and is not alphabetical. libotr's headers include none of
 * their own dependencies, so proto.h and tlv.h have to precede message.h —
 * otherwise OtrlFragmentPolicy and OtrlTLV are undeclared when message.h is
 * parsed, and the build fails inside the framework's headers.
 *
 * clang-format sorts includes alphabetically, which reintroduces exactly that
 * break, so this block is fenced off.
 */
// clang-format off
#import <libotr/context.h>
#import <libotr/proto.h>
#import <libotr/tlv.h>
#import <libotr/message.h>
#import <libotr/privkey.h>
// clang-format on
