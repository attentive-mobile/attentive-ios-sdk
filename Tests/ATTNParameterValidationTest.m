//
//  ATTNParameterValidationTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/29/22.
//

#import <XCTest/XCTest.h>
#import "AttNParameterValidation.h"

@interface ATTNParameterValidationTest : XCTestCase

@end

@implementation ATTNParameterValidationTest

- (void)testIsNotNil_givenNil_returnsFalse {
    XCTAssertFalse([ATTNParameterValidation isNotNil:nil]);
}

- (void)testIsNotNil_givenNotNil_returnsTrue {
    XCTAssertTrue([ATTNParameterValidation isNotNil:[[NSString alloc] init]]);
}

- (void)testIsStringAndNotEmpty_givenNil_returnsFalse {
    XCTAssertFalse([ATTNParameterValidation isStringAndNotEmpty:nil]);
}

- (void)testIsStringAndNotEmpty_givenDictionary_returnsFalse {
    XCTAssertFalse([ATTNParameterValidation isStringAndNotEmpty:[[NSDictionary alloc] init]]);
}

- (void)testIsStringAndNotEmpty_givenEmptyString_returnsFalse {
    XCTAssertFalse([ATTNParameterValidation isStringAndNotEmpty:@""]);
}

- (void)testIsStringAndNotEmpty_givenEmptyString_returnsTrue {
    XCTAssertTrue([ATTNParameterValidation isStringAndNotEmpty:@"notEmpty"]);
}

- (void)testVerifyStringOrNil_givenNil_succeeds {
    XCTAssertNoThrow([ATTNParameterValidation verifyStringOrNil:nil inputName:@"inputNameValue"]);
}

- (void)testVerifyStringOrNil_givenDictionary_throws {
    XCTAssertThrows([ATTNParameterValidation verifyStringOrNil:@{@"hi":@"hello"} inputName:@"inputNameValue"]);
}

- (void)testVerifyStringOrNil_givenEmptyString_throws {
    XCTAssertThrows([ATTNParameterValidation verifyStringOrNil:@"" inputName:@"inputNameValue"]);
}

- (void)testVerifyStringOrNil_givenNonEmptyString_succeeds {
    XCTAssertNoThrow([ATTNParameterValidation verifyStringOrNil:@"notEmpty" inputName:@"inputNameValue"]);
}

- (void)testVerify1DStringDictionaryOrNil_givenNil_succeeds {
    XCTAssertNoThrow([ATTNParameterValidation verify1DStringDictionaryOrNil:nil inputName:@"inputNameValue"]);
}

- (void)testVerify1DStringDictionaryOrNil_givenString_throws {
    XCTAssertThrows([ATTNParameterValidation verify1DStringDictionaryOrNil:@"someString" inputName:@"inputNameValue"]);
}

- (void)testVerify1DStringDictionaryOrNil_givenEmptyDictionary_succeeds {
    XCTAssertNoThrow([ATTNParameterValidation verify1DStringDictionaryOrNil:@{} inputName:@"inputNameValue"]);
}

- (void)testVerify1DStringDictionaryOrNil_givenNonEmptyDictionary_succeeds {
    XCTAssertNoThrow([ATTNParameterValidation verify1DStringDictionaryOrNil:@{@"someKey":@"somevalue"} inputName:@"inputNameValue"]);
}

@end
