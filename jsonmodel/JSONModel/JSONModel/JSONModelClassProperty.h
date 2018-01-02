//
//  JSONModelClassProperty.h
//  JSONModel
//

#import <Foundation/Foundation.h>

/**
 * **You do not need to instantiate this class yourself.** This class is used internally by JSONModel
 * to inspect the declared properties of your model class.
 *
 * Class to contain the information, representing a class property
 * It features the property's name, type, whether it's a required property,
 * and (optionally) the class protocol
 * 这个类的是JSONModel的内部使用的类，主要是用来描述一个类的属性信息，属性名、属性的类型、如果是结构体，结构体的名字，属性遵守的协议，是不是可选的，是不是标准的JSON类型，是不是一个可变的，自定义的getter&setter方法
 */
@interface JSONModelClassProperty : NSObject

// deprecated
@property (assign, nonatomic) BOOL isIndex DEPRECATED_ATTRIBUTE;

/** The name of the declared property (not the ivar name) */
//属性名
@property (copy, nonatomic) NSString *name;

/** A property class type  */
//属性类型
@property (assign, nonatomic) Class type;

/** Struct name if a struct */
//结构体名
@property (strong, nonatomic) NSString *structName;

/** The name of the protocol the property conforms to (or nil) */
//协议名
@property (copy, nonatomic) NSString *protocol;

/** If YES, it can be missing in the input data, and the input would be still valid */
//是否可选
@property (assign, nonatomic) BOOL isOptional;

/** If YES - don't call any transformers on this property's value */
//是不是标准的JSON类型
@property (assign, nonatomic) BOOL isStandardJSONType;

/** If YES - create a mutable object for the value of the property */
//是否是可变的
@property (assign, nonatomic) BOOL isMutable;

/** a custom getter for this property, found in the owning model */
//自定义的getter方法
@property (assign, nonatomic) SEL customGetter;

/** custom setters for this property, found in the owning model */
//自定义的setter方法
@property (strong, nonatomic) NSMutableDictionary *customSetters;

@end
