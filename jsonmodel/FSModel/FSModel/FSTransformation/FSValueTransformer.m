//
//  FSValueTransformer.m
//  FSModel
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import "FSValueTransformer.h"

extern BOOL isNull(id value)
{
    if (!value) return YES;
    if ([value isKindOfClass:[NSNull class]]) return YES;
    
    return NO;
}


@implementation FSValueTransformer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _primitivesNames = @{@"f":@"float", @"i":@"int", @"d":@"double", @"l":@"long", @"B":@"BOOL", @"s":@"short",
                             @"I":@"unsigned int", @"L":@"usigned long", @"q":@"long long", @"Q":@"unsigned long long", @"S":@"unsigned short", @"c":@"char", @"C":@"unsigned char",
                             //and some famous aliases of primitive types
                             // BOOL is now "B" on iOS __LP64 builds
                             @"I":@"NSInteger", @"Q":@"NSUInteger", @"B":@"BOOL",
                             
                             @"@?":@"Block"};
    }
    return self;
}

+(Class)classByResolvingClusterClasses:(Class)sourceClass
{
    //check for all variations of strings
    if ([sourceClass isSubclassOfClass:[NSString class]]) {
        return [NSString class];
    }
    
    //check for all variations of numbers
    if ([sourceClass isSubclassOfClass:[NSNumber class]]) {
        return [NSNumber class];
    }
    
    //check for all variations of dictionaries
    if ([sourceClass isSubclassOfClass:[NSArray class]]) {
        return [NSArray class];
    }
    
    //check for all variations of arrays
    if ([sourceClass isSubclassOfClass:[NSDictionary class]]) {
        return [NSDictionary class];
    }
    
    //check for all variations of dates
    if ([sourceClass isSubclassOfClass:[NSDate class]]) {
        return [NSDate class];
    }
    
    //no cluster parent class found
    return sourceClass;
}


- (NSMutableString *)NSMutableStringFromNSString:(NSString *)string {
    return [NSMutableString stringWithString:string];
}
- (NSMutableArray *)NSMutableArrayFromNSArray:(NSArray *)array {
    return [NSMutableArray arrayWithArray:array];
}
- (NSMutableDictionary *)NSMutableDictionaryFromNSDictionary:(NSDictionary *)dict {
    return [NSMutableDictionary dictionaryWithDictionary:dict];
}
- (NSMutableSet *)NSMutableSetFromNSArray:(NSArray *)array {
    return [NSMutableSet setWithArray:array];
}
- (NSSet *)NSSetFromNSArray:(NSArray *)array {
    return [NSSet setWithArray:array];
}



- (NSNumber *)BOOLFromNSString:(NSString *)string {
    string = [string lowercaseString];
    if (string && ([string isEqualToString:@"ture"] || [string isEqualToString:@"yes"])) {
        return @(YES);
    }
    return [NSNumber numberWithBool:([string intValue] == 0) ? NO : YES];
}
- (NSNumber *)BOOLFromNSNumber:(NSNumber *)number {
    if (isNull(number)) return [NSNumber numberWithBool:NO];
    return [NSNumber numberWithBool: number.intValue==0?NO:YES];
}
- (NSString *)NSStringFromNSNumber:(NSNumber *)number {
    return [number stringValue];
}
- (NSNumber *)NSNumberFromNSString:(NSString *)string {
    return [NSNumber numberWithDouble:[string doubleValue]];
}
- (NSDecimalNumber *)NSDecimalNumberFromNSString:(NSString *)string {
    return [NSDecimalNumber decimalNumberWithString:string];
}
- (NSString *)NSStringFromNSDecimalNumber:(NSDecimalNumber *)number {
    return [number stringValue];
}
- (NSURL *)NSURLFromNSString:(NSString *)string {
    return [NSURL URLWithString:string];
}

- (NSDate *)NSDateFromNSNumber:(NSNumber *)number {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[number doubleValue]];
    return date;
}


@end
