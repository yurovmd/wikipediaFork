#import "WKSourceEditorFormatter.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSourceEditorFormatterLink : WKSourceEditorFormatter
- (BOOL)attributedString:(NSMutableAttributedString *)attributedString isSimpleLinkInRange:(NSRange)range;
- (BOOL)attributedString:(NSMutableAttributedString *)attributedString isLinkWithNestedLinkInRange:(NSRange)range;
@end

NS_ASSUME_NONNULL_END
