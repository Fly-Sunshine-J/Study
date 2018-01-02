//
//  FSValueTransformer.h
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import <Foundation/Foundation.h>

extern BOOL isNull(id value);

@interface FSValueTransformer : NSObject

@property (nonatomic, strong, readonly) NSDictionary *primitivesNames;

+ (Class)classByResolvingClusterClasses:(Class)sourceClass;

- (NSMutableString *)NSMutableStringFromNSString:(NSString *)string;
- (NSMutableArray *)NSMutableArrayFromNSArray:(NSArray *)array;
- (NSMutableDictionary *)NSMutableDictionaryFromNSDictionary:(NSDictionary *)string;
- (NSMutableSet *)NSMutableSetFromNSArray:(NSArray *)array;
- (NSSet *)NSSetFromNSArray:(NSArray *)array;

- (NSNumber *)BOOLFromNSString:(NSString *)string;
- (NSNumber *)BOOLFromNSNumber:(NSNumber *)number;
- (NSString *)NSStringFromNSNumber:(NSNumber *)number;
- (NSNumber *)NSNumberFromNSString:(NSString *)string;
- (NSDecimalNumber *)NSDecimalNumberFromNSString:(NSString *)string;
- (NSString *)NSStringFromNSDecimalNumber:(NSDecimalNumber *)number;
- (NSURL *)NSURLFromNSString:(NSString *)string;
- (NSDate *)NSDateFromNSNumber:(NSNumber *)number;

@end
