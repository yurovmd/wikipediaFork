#import "MWKDataStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface MWKDataStore (Testing)

/**
 * Create a data store which persists objects in a random folder in the application's @c tmp directory.
 * @see WMFRandomTemporaryDirectoryPath()
 */
+ (void)createTemporaryDataStoreWithCompletion:(void (^)(MWKDataStore *))completion;

@end

NS_ASSUME_NONNULL_END
