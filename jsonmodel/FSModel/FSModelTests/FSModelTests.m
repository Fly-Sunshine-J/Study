//
//  FSModelTests.m
//  FSModelTests
//
//  Created by vcyber on 2017/11/24.
//  Copyright © 2017年 vcyber. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FSModelLib.h"

@protocol People
@end

@interface Dog:FSModel
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int age;
@end
@implementation Dog
@end

@interface People:FSModel
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int age;
@property (nonatomic, strong) NSSet<People> *friends;
@property (nonatomic, strong) Dog<Optional> *dog;
@end
@implementation People
@end


@interface FSModelTests : XCTestCase

@end

@implementation FSModelTests

- (void)setUp {
    [super setUp];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    
    NSDictionary *dict = @{
                           @"name":@"foo",
                           @"age":@(18),
                           @"friends":@[@{
                                            @"name":@"jack",
                                            @"age":@(18),
                                            @"friends":@[],
                                            },
                                        @{
                                            @"name":@"lili",
                                            @"age":@(17),
                                            @"dog":@{
                                                    @"name":@"wangcai",
                                                    @"age":@(2)
                                                    },
                                            @"friends":@[@{
                                                             @"name":@"mark",
                                                             @"age":@(19),
                                                             @"friends":@[]
                                                             }]
                                            }
                                        ]
                           };
    NSError *err;
    People *p = [[People alloc] initWithDictionary:dict error:&err];
    XCTAssertNotNil(p, @"初始化失败");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
