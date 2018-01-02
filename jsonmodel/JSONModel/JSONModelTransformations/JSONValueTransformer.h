//
//  JSONValueTransformer.h
//  JSONModel
//

#import <Foundation/Foundation.h>

/////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - extern definitions
/**
 * Boolean function to check for null values. Handy when you need to both check
 * for nil and [NSNUll null]
 */
extern BOOL isNull(id value);

/////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - JSONValueTransformer interface
/**
 * **You don't need to call methods of this class manually.**
 *
 * Class providing methods to transform values from one class to another.
 * You are given a number of built-in transformers, but you are encouraged to
 * extend this class with your own categories to add further value transformers.
 * Just few examples of what can you add to JSONValueTransformer: hex colors in JSON to UIColor,
 * hex numbers in JSON to NSNumber model properties, base64 encoded strings in JSON to UIImage properties, and more.
 *
 * The class is invoked by JSONModel while transforming incoming
 * JSON types into your target class property classes, and vice versa.
 * One static copy is create and store in the JSONModel class scope.
 */
@interface JSONValueTransformer : NSObject

@property (strong, nonatomic, readonly) NSDictionary *primitivesNames;

/** @name Resolving cluster class names */
/**
 * This method returns the umbrella class for any standard class cluster members.
 * For example returns NSString when given as input NSString, NSMutableString, __CFString and __CFConstantString
 * The method currently looksup a pre-defined list.
 * @param sourceClass the class to get the umbrella class for
 * @return Class
 * 将类簇的其他子类全部转为同一个类，例如将NSString，NSMutableString,__CFString,__CFConstantString全部转为NSString
 */
+ (Class)classByResolvingClusterClasses:(Class)sourceClass;

#pragma mark - NSMutableString <-> NSString
/** @name Transforming to Mutable copies */
/**
 * Transforms a string value to a mutable string value
 * @param string incoming string
 * @return mutable string
 * 将不可变的NSString转为可变的NSMutableString
 */
- (NSMutableString *)NSMutableStringFromNSString:(NSString *)string;

#pragma mark - NSMutableArray <-> NSArray
/**
 * Transforms an array to a mutable array
 * @param array incoming array
 * @return mutable array
 * 将不可变的NSArray转为可变的NSMutableArray
 */
- (NSMutableArray *)NSMutableArrayFromNSArray:(NSArray *)array;

#pragma mark - NSMutableDictionary <-> NSDictionary
/**
 * Transforms a dictionary to a mutable dictionary
 * @param dict incoming dictionary
 * @return mutable dictionary
 * 将不可变的NSDictionary转为可变的NSMutableDictionary
 */
- (NSMutableDictionary *)NSMutableDictionaryFromNSDictionary:(NSDictionary *)dict;

#pragma mark - NSSet <-> NSArray
/** @name Transforming Sets */
/**
 * Transforms an array to a set
 * @param array incoming array
 * @return set with the array's elements
 * 将不可变的数组转化为不可变的集合
 */
- (NSSet *)NSSetFromNSArray:(NSArray *)array;

/**
 * Transforms an array to a mutable set
 * @param array incoming array
 * @return mutable set with the array's elements
 * 将不可变的数组转化为可变的集合
 */
- (NSMutableSet *)NSMutableSetFromNSArray:(NSArray *)array;

/**
 * Transforms a set to an array
 * @param set incoming set
 * @return an array with the set's elements
 * 将不可变集合转化为数组
 */
- (NSArray *)JSONObjectFromNSSet:(NSSet *)set;

/**
 * Transforms a mutable set to an array
 * @param set incoming mutable set
 * @return an array with the set's elements
 * 将可变的集合转化为不可变的数组
 */
- (NSArray *)JSONObjectFromNSMutableSet:(NSMutableSet *)set;

#pragma mark - BOOL <-> number/string
/** @name Transforming JSON types */
/**
 * Transforms a number object to a bool number object
 * @param number the number to convert
 * @return the resulting number
 * 将一个NSNumber转化为一个Bool类的NSNumber
 */
- (NSNumber *)BOOLFromNSNumber:(NSNumber *)number;

/**
 * Transforms a number object to a bool number object
 * @param string the string value to convert, "0" converts to NO, everything else to YES
 * @return the resulting number
 * 将字符串转为Bool类型的NSNumber，字符串是yes、true均会转化为1
 */
- (NSNumber *)BOOLFromNSString:(NSString *)string;

/**
 * Transforms a BOOL value to a bool number object
 * @param number an NSNumber value coming from the model
 * @return the result number
 */
- (NSNumber *)JSONObjectFromBOOL:(NSNumber *)number;

#pragma mark - string <-> number
/**
 * Transforms a string object to a number object
 * @param string the string to convert
 * @return the resulting number
 * 将字符串转化为NSNumber
 */
- (NSNumber *)NSNumberFromNSString:(NSString *)string;

/**
 * Transforms a number object to a string object
 * @param number the number to convert
 * @return the resulting string
 * 将NSNumber转化为字符串
 */
- (NSString *)NSStringFromNSNumber:(NSNumber *)number;

/**
 * Transforms a string object to a nsdecimalnumber object
 * @param string the string to convert
 * @return the resulting number
 * 将字符串转化为NSDecimalNumber
 */
- (NSDecimalNumber *)NSDecimalNumberFromNSString:(NSString *)string;

/**
 * Transforms a nsdecimalnumber object to a string object
 * @param number the number to convert
 * @return the resulting string
 * 将NSDecimalNumber转为字符串
 */
- (NSString *)NSStringFromNSDecimalNumber:(NSDecimalNumber *)number;


#pragma mark - string <-> url
/** @name Transforming URLs */
/**
 * Transforms a string object to an NSURL object
 * @param string the string to convert
 * @return the resulting url object
 * 将字符串转化为NSURL
 */
- (NSURL *)NSURLFromNSString:(NSString *)string;

/**
 * Transforms an NSURL object to a string
 * @param url the url object to convert
 * @return the resulting string
 * 将NSURL转化为NSString
 */
- (NSString *)JSONObjectFromNSURL:(NSURL *)url;

#pragma mark - string <-> time zone

/** @name Transforming NSTimeZone */
/**
 * Transforms a string object to an NSTimeZone object
 * @param string the string to convert
 * @return the resulting NSTimeZone object
 * 将字符串转化为时区
 */
- (NSTimeZone *)NSTimeZoneFromNSString:(NSString *)string;

/**
 * Transforms an NSTimeZone object to a string
 * @param timeZone the time zone object to convert
 * @return the resulting string
 * 将时区转化为字符串
 */
- (NSString *)JSONObjectFromNSTimeZone:(NSTimeZone *)timeZone;

#pragma mark - string <-> date
/** @name Transforming Dates */
/**
 * The following two methods are not public. This way if there is a category on converting
 * dates it'll override them. If there isn't a category the default methods found in the .m
 * file will be invoked. If these are public a warning is produced at the point of overriding
 * them in a category, so they have to stay hidden here.
 */

//- (NSDate *)NSDateFromNSString:(NSString *)string;
//- (NSString *)JSONObjectFromNSDate:(NSDate *)date;

#pragma mark - number <-> date

/**
 * Transforms a number to an NSDate object
 * @param number the number to convert
 * @return the resulting date
 * 将NSNumber转化为日期
 */
- (NSDate *)NSDateFromNSNumber:(NSNumber *)number;

@end
