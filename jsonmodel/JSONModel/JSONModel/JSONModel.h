//
//  JSONModel.h
//  JSONModel
//

#import <Foundation/Foundation.h>

#import "JSONModelError.h"
#import "JSONValueTransformer.h"
#import "JSONKeyMapper.h"

/////////////////////////////////////////////////////////////////////////////////////////////
#if TARGET_IPHONE_SIMULATOR
#define JMLog( s, ... ) NSLog( @"[%@:%d] %@", [[NSString stringWithUTF8String:__FILE__] \
lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define JMLog( s, ... )
#endif
/////////////////////////////////////////////////////////////////////////////////////////////

DEPRECATED_ATTRIBUTE
@protocol ConvertOnDemand
@end

DEPRECATED_ATTRIBUTE
@protocol Index
@end

#pragma mark - Property Protocols
/**
 * Protocol for defining properties in a JSON Model class that should not be considered at all
 * neither while importing nor when exporting JSON.
 *
 * @property (strong, nonatomic) NSString<Ignore> *propertyName;
 * 在一个继承JSONModel类定义属性的时候使用，表示可以忽略这个属性
 */

@protocol Ignore
@end

/**
 * Protocol for defining optional properties in a JSON Model class. Use like below to define
 * model properties that are not required to have values in the JSON input:
 *
 * @property (strong, nonatomic) NSString<Optional> *propertyName;
 *在一个继承JSONModel类定义属性的时候使用，表示可以可选这个属性
 */
@protocol Optional
@end

/**
 * Make all objects compatible to avoid compiler warnings
 */
@interface NSObject (JSONModelPropertyCompatibility) <Optional, Ignore>
@end

/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - JSONModel protocol
/**
 * A protocol describing an abstract JSONModel class
 * JSONModel conforms to this protocol, so it can use itself abstractly
 * JOSNModel遵守的协议
 */
@protocol AbstractJSONModelProtocol <NSCopying, NSCoding>

@required
/**
 * All JSONModel classes should implement initWithDictionary:
 *
 * For most classes the default initWithDictionary: inherited from JSONModel itself
 * should suffice, but developers have the option to also overwrite it if needed.
 *
 * @param dict a dictionary holding JSON objects, to be imported in the model.
 * @param err an error or NULL
 * 所有的JSONModel类都应该实现这个方法，这个方法可以重写在你需要的时候，返回JSONModel类型的实例
 */

- (instancetype)initWithDictionary:(NSDictionary *)dict error:(NSError **)err;


/**
 * All JSONModel classes should implement initWithData:error:
 *
 * For most classes the default initWithData: inherited from JSONModel itself
 * should suffice, but developers have the option to also overwrite it if needed.
 *
 * @param data representing a JSON response (usually fetched from web), to be imported in the model.
 * @param error an error or NULL
 * 所有的JSONModel类都应该实现这个方法，这个方法可以重写在你需要的时候，返回JSONModel类型的实例
 */
- (instancetype)initWithData:(NSData *)data error:(NSError **)error;

/**
 * All JSONModel classes should be able to export themselves as a dictionary of
 * JSON compliant objects.
 *
 * For most classes the inherited from JSONModel default toDictionary implementation
 * should suffice.
 *
 * @return NSDictionary dictionary of JSON compliant objects
 * @exception JSONModelTypeNotAllowedException thrown when one of your model's custom class properties
 * does not have matching transformer method in an JSONValueTransformer.
 * 将一个JSONModel类型的模型转化为字典
 */
- (NSDictionary *)toDictionary;

/**
 * Export a model class to a dictionary, including only given properties
 *
 * @param propertyNames the properties to export; if nil, all properties exported
 * @return NSDictionary dictionary of JSON compliant objects
 * @exception JSONModelTypeNotAllowedException thrown when one of your model's custom class properties
 * does not have matching transformer method in an JSONValueTransformer.
 * 给指定的属性名导出字典，如果参数传nil，默认全部导出
 */
- (NSDictionary *)toDictionaryWithKeys:(NSArray *)propertyNames;
@end

/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - JSONModel interface
/**
 * The JSONModel is an abstract model class, you should not instantiate it directly,
 * as it does not have any properties, and therefore cannot serve as a data model.
 * Instead you should subclass it, and define the properties you want your data model
 * to have as properties of your own class.
 * JSONModel是一个抽象类，不应该直接使用，因为它没有属性，不能作为一个数据模型，应该用它的子类去实例化该对象
 */
@interface JSONModel : NSObject <AbstractJSONModelProtocol, NSSecureCoding>

// deprecated
+ (NSMutableArray *)arrayOfModelsFromDictionaries:(NSArray *)array DEPRECATED_MSG_ATTRIBUTE("use arrayOfModelsFromDictionaries:error:");
+ (void)setGlobalKeyMapper:(JSONKeyMapper *)globalKeyMapper DEPRECATED_MSG_ATTRIBUTE("override +keyMapper in a base model class instead");
+ (NSString *)protocolForArrayProperty:(NSString *)propertyName DEPRECATED_MSG_ATTRIBUTE("use classForCollectionProperty:");
- (void)mergeFromDictionary:(NSDictionary *)dict useKeyMapping:(BOOL)useKeyMapping DEPRECATED_MSG_ATTRIBUTE("use mergeFromDictionary:useKeyMapping:error:");
- (NSString *)indexPropertyName DEPRECATED_ATTRIBUTE;
- (NSComparisonResult)compare:(id)object DEPRECATED_ATTRIBUTE;

/** @name Creating and initializing models */

/**
 * Create a new model instance and initialize it with the JSON from a text parameter. The method assumes UTF8 encoded input text.
 * @param string JSON text data
 * @param err an initialization error or nil
 * @exception JSONModelTypeNotAllowedException thrown when unsupported type is found in the incoming JSON,
 * or a property type in your model is not supported by JSONValueTransformer and its categories
 * @see initWithString:usingEncoding:error: for use of custom text encodings
 * 使用一个json字符串去实例化对象，默认字符串编码使用的是UTF-8编码
 */
- (instancetype)initWithString:(NSString *)string error:(JSONModelError **)err;

/**
 * Create a new model instance and initialize it with the JSON from a text parameter using the given encoding.
 * @param string JSON text data
 * @param encoding the text encoding to use when parsing the string (see NSStringEncoding)
 * @param err an initialization error or nil
 * @exception JSONModelTypeNotAllowedException thrown when unsupported type is found in the incoming JSON,
 * or a property type in your model is not supported by JSONValueTransformer and its categories
 *
 */
- (instancetype)initWithString:(NSString *)string usingEncoding:(NSStringEncoding)encoding error:(JSONModelError **)err;

/** @name Exporting model contents */

/**
 * Export the whole object to a JSON data text string
 * @return JSON text describing the data model
 * 将JSONModel转化成JSON字符串
 */
- (NSString *)toJSONString;

/**
 * Export the whole object to a JSON data text string
 * @return JSON text data describing the data model
 * 将JSONModel转化为二进制
 */
- (NSData *)toJSONData;

/**
 * Export the specified properties of the object to a JSON data text string
 * @param propertyNames the properties to export; if nil, all properties exported
 * @return JSON text describing the data model
 * 将指定的属性名的JSONModel模型转化为字符串，如果参数传nil，默认全部转出
 */
- (NSString *)toJSONStringWithKeys:(NSArray *)propertyNames;

/**
 * Export the specified properties of the object to a JSON data text string
 * @param propertyNames the properties to export; if nil, all properties exported
 * @return JSON text data describing the data model
 * 将指定的属性的JSONModel模型转化为二进制，如果参数传nil，默认全部转出
 */
- (NSData *)toJSONDataWithKeys:(NSArray *)propertyNames;

/** @name Batch methods */

/**
 * If you have a list of dictionaries in a JSON feed, you can use this method to create an NSArray
 * of model objects. Handy when importing JSON data lists.
 * This method will loop over the input list and initialize a data model for every dictionary in the list.
 *
 * @param array list of dictionaries to be imported as models
 * @return list of initialized data model objects
 * @exception JSONModelTypeNotAllowedException thrown when unsupported type is found in the incoming JSON,
 * or a property type in your model is not supported by JSONValueTransformer and its categories
 * @exception JSONModelInvalidDataException thrown when the input data does not include all required keys
 * @see arrayOfDictionariesFromModels:
 */

/**
 将一个字典数组转化为模型数组

 @param array 字典数组
 @param err 错误信息
 @return 模型数组
 */
+ (NSMutableArray *)arrayOfModelsFromDictionaries:(NSArray *)array error:(NSError **)err;

/**
 将一个数组的二进制转化为模型数组

 @param data 数组二进制
 @param err 错误信息
 @return 模型数组
 */
+ (NSMutableArray *)arrayOfModelsFromData:(NSData *)data error:(NSError **)err;

/**
 将一个json数组字符串转化为模型数组

 @param string json数组字符串
 @param err 错误信息
 @return 模型数组
 */
+ (NSMutableArray *)arrayOfModelsFromString:(NSString *)string error:(NSError **)err;

/**
 将字典转化为模型字典（key-model）

 @param dictionary 字典
 @param err 错误信息
 @return 模型字典（key-model）
 */
+ (NSMutableDictionary *)dictionaryOfModelsFromDictionary:(NSDictionary *)dictionary error:(NSError **)err;

/**
 将一个字典的二进制转化为模型字典

 @param data 二进制
 @param err  错误信息
 @return 模型字典
 */
+ (NSMutableDictionary *)dictionaryOfModelsFromData:(NSData *)data error:(NSError **)err;

/**
 将一个json字典字符串转化为模型字典

 @param string json字典字符串
 @param err 错误信息
 @return 模型字典
 */
+ (NSMutableDictionary *)dictionaryOfModelsFromString:(NSString *)string error:(NSError **)err;

/**
 * If you have an NSArray of data model objects, this method takes it in and outputs a list of the
 * matching dictionaries. This method does the opposite of arrayOfObjectsFromDictionaries:
 * @param array list of JSONModel objects
 * @return a list of NSDictionary objects
 * @exception JSONModelTypeNotAllowedException thrown when unsupported type is found in the incoming JSON,
 * or a property type in your model is not supported by JSONValueTransformer and its categories
 * @see arrayOfModelsFromDictionaries:
 */

/**
 将一个模型数组转化为一个字典数组

 @param array 模型数组
 @return 字典数组
 */
+ (NSMutableArray *)arrayOfDictionariesFromModels:(NSArray *)array;

/**
 将一个模型字典（key-model）转化为字典

 @param dictionary 模型字典
 @return 字典
 */
+ (NSMutableDictionary *)dictionaryOfDictionariesFromModels:(NSDictionary *)dictionary;

/** @name Validation */

/**
 * Overwrite the validate method in your own models if you need to perform some custom validation over the model data.
 * This method gets called at the very end of the JSONModel initializer, thus the model is in the state that you would
 * get it back when initialized. Check the values of any property that needs to be validated and if any invalid values
 * are encountered return NO and set the error parameter to an NSError object. If the model is valid return YES.
 *
 * NB: Only setting the error parameter is not enough to fail the validation, you also need to return a NO value.
 *
 * @param error a pointer to an NSError object, to pass back an error if needed
 * @return a BOOL result, showing whether the model data validates or not. You can use the convenience method
 * [JSONModelError errorModelIsInvalid] to set the NSError param if the data fails your custom validation
 *  验证数据模型是否可用，你可以重写这个方法，自己实现自己的验证方法,NO代表不可用，YES代表可用，如果返回NO，模型会创建失败
 */
- (BOOL)validate:(NSError **)error;

/** @name Key mapping */
/**
 * Overwrite in your models if your property names don't match your JSON key names.
 * Lookup JSONKeyMapper docs for more details.
 * 如果你的属性名和json的key不对应，你可以重写这个方法来进行匹配
 */
+ (JSONKeyMapper *)keyMapper;

/**
 * Indicates whether the property with the given name is Optional.
 * To have a model with all of its properties being Optional just return YES.
 * This method returns by default NO, since the default behaviour is to have all properties required.
 * @param propertyName the name of the property
 * @return a BOOL result indicating whether the property is optional
 * 根据属性名判断该属性是不是可选的，默认返回的全部是NO，不是可选的，可以重写该方法，使得某些属性是可选的
 */
+ (BOOL)propertyIsOptional:(NSString *)propertyName;

/**
 * Indicates whether the property with the given name is Ignored.
 * To have a model with all of its properties being Ignored just return YES.
 * This method returns by default NO, since the default behaviour is to have all properties required.
 * @param propertyName the name of the property
 * @return a BOOL result indicating whether the property is ignored
 * 根据属性名判断该属性是不是可忽略的，默认返回的全部是NO，不可忽略的，可以重写该方法，使得某些属性是可忽略的
 */
+ (BOOL)propertyIsIgnored:(NSString *)propertyName;

/**
 * Indicates the class used for the elements of a collection property.
 * Rather than using:
 *     @property (strong) NSArray <MyType> *things;
 * You can implement classForCollectionProperty: and keep your property
 * defined like:
 *     @property (strong) NSArray *things;
 * @param propertyName the name of the property
 * @return Class the class used to deserialize the elements of the collection
 *
 * Example in Swift 3.0:
 * override static func classForCollectionProperty(propertyName: String) -> AnyClass? {
 *   switch propertyName {
 *     case "childModel":
 *       return ChildModel.self
 *     default:
 *       return nil
 *   }
 * }
 * 根据集合属性名，返回集合里面的类型
 */
+ (Class)classForCollectionProperty:(NSString *)propertyName NS_SWIFT_NAME(classForCollectionProperty(propertyName:));

/**
 * Merges values from the given dictionary into the model instance.
 * @param dict dictionary with values
 * @param useKeyMapping if YES the method will use the model's key mapper and the global key mapper, if NO
 * it'll just try to match the dictionary keys to the model's properties
 * 将字典内的key-value配合keyMaping转化到模型中
 */
- (BOOL)mergeFromDictionary:(NSDictionary *)dict useKeyMapping:(BOOL)useKeyMapping error:(NSError **)error;

@end
