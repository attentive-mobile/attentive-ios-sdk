//
//  ATTNPersistentStorageTest.m
//  attentive-ios-sdk Tests
//
//  Created by Wyatt Davis on 11/29/22.
//

#import <XCTest/XCTest.h>
#import "ATTNPersistentStorage.h"

@interface ATTNPersistentStorageTest : XCTestCase

@end

@implementation ATTNPersistentStorageTest {
  ATTNPersistentStorage* persistentStorage;
}

- (void)setUp {
  [self resetUserDefaults];
  persistentStorage = [[ATTNPersistentStorage alloc] init];
}

- (void)resetUserDefaults {
  NSString* domainName = [[NSBundle mainBundle] bundleIdentifier];
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domainName];
}

- (void)tearDown {
  // We delete in setup, but delete here too just in case
  [self resetUserDefaults];
}

static NSString* const KEY = @"savedKey";
static NSString* const VALUE = @"savedValue";

- (void)testSaveObject {
  [persistentStorage saveObject:@"savedValue" forKey:@"someKey"];

  XCTAssertTrue([@"savedValue" isEqualToString:[persistentStorage readStringForKey:@"someKey"]]);
}

- (void)testSaveObject_givenValidString_saves {
  [persistentStorage saveObject:VALUE forKey:KEY];

  XCTAssertTrue([VALUE isEqualToString:[persistentStorage readStringForKey:KEY]]);
}

- (void)testSaveObject_overwriteWithSameValue_saves {
  [persistentStorage saveObject:VALUE forKey:KEY];

  XCTAssertTrue([VALUE isEqualToString:[persistentStorage readStringForKey:KEY]]);

  [persistentStorage saveObject:VALUE forKey:KEY];

  XCTAssertTrue([VALUE isEqualToString:[persistentStorage readStringForKey:KEY]]);
}

- (void)testSaveObject_overwriteWithDifferentValue_savesDifferentValue {
  [persistentStorage saveObject:VALUE forKey:KEY];

  XCTAssertTrue([VALUE isEqualToString:[persistentStorage readStringForKey:KEY]]);

  [persistentStorage saveObject:@"newValue" forKey:KEY];

  XCTAssertTrue([@"newValue" isEqualToString:[persistentStorage readStringForKey:KEY]]);
}

- (void)testReadStringForKey_noPreviousObjectSaved_returnsNil {
  XCTAssertNil([persistentStorage readStringForKey:KEY]);
}

- (void)testReadStringForKey_previousObjectSaved_returnsObject {
  [persistentStorage saveObject:VALUE forKey:KEY];

  XCTAssertTrue([VALUE isEqualToString:[persistentStorage readStringForKey:KEY]]);
}

- (void)testDeleteObjectForKey_noPreviousObjectSaved_noop {
  XCTAssertNoThrow([persistentStorage deleteObjectForKey:KEY]);
}

- (void)testDeleteObjectForKey_previousObjectSaved_deletes {
  [persistentStorage saveObject:VALUE forKey:KEY];

  XCTAssertTrue([VALUE isEqualToString:[persistentStorage readStringForKey:KEY]]);

  [persistentStorage deleteObjectForKey:KEY];

  XCTAssertNil([persistentStorage readStringForKey:KEY]);
}

@end
