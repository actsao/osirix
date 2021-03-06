/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/


#import "NSUserDefaultsController+N2.h"


@implementation NSUserDefaultsController (N2)

-(NSString*)stringForKey:(NSString*)key {
	id obj = [self valueForValuesKey:key];
	if (![obj isKindOfClass:[NSString class]]) return NULL;
	return obj;
}

-(NSArray*)arrayForKey:(NSString*)key {
	id obj = [self valueForValuesKey:key];
	if (![obj isKindOfClass:[NSArray class]]) return NULL;
	return obj;
}

-(NSDictionary*)dictionaryForKey:(NSString*)key {
	id obj = [self valueForValuesKey:key];
	if (![obj isKindOfClass:[NSDictionary class]]) return NULL;
	return obj;
}

-(NSData*)dataForKey:(NSString*)key {
	id obj = [self valueForValuesKey:key];
	if (![obj isKindOfClass:[NSData class]]) return NULL;
	return obj;
}

-(NSInteger)integerForKey:(NSString*)key {
	NSNumber* obj = [self valueForValuesKey:key];
	if (![obj respondsToSelector:@selector(integerValue)]) return 0;
	return [obj integerValue];
}

-(float)floatForKey:(NSString*)key {
	NSNumber* obj = [self valueForValuesKey:key];
	if (![obj respondsToSelector:@selector(floatValue)]) return 0;
	return [obj floatValue];
}

-(double)doubleForKey:(NSString*)key {
	NSNumber* obj = [self valueForValuesKey:key];
	if (![obj respondsToSelector:@selector(doubleValue)]) return 0;
	return [obj doubleValue];
}

-(BOOL)boolForKey:(NSString*)key {
	NSNumber* obj = [self valueForValuesKey:key];
	if (![obj respondsToSelector:@selector(boolValue)]) return NO;
	return [obj boolValue];
}

-(void)setString:(NSString*)value forKey:(NSString*)defaultName {
	if (![value isKindOfClass:[NSString class]])
		[NSException raise:NSInvalidArgumentException format:@"Value must be of class NSString"];
	[self setValue:value forValuesKey:defaultName];
}

-(void)setArray:(NSArray*)value forKey:(NSString*)defaultName {
	if (![value isKindOfClass:[NSArray class]])
		[NSException raise:NSInvalidArgumentException format:@"Value must be of class NSArray"];
	[self setValue:value forValuesKey:defaultName];
}

-(void)setDictionary:(NSDictionary*)value forKey:(NSString*)defaultName {
	if (![value isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:@"Value must be of class NSDictionary"];
	[self setValue:value forValuesKey:defaultName];
}

-(void)setData:(NSData*)value forKey:(NSString*)defaultName {
	if (![value isKindOfClass:[NSData class]])
		[NSException raise:NSInvalidArgumentException format:@"Value must be of class NSData"];
	[self setValue:value forValuesKey:defaultName];
}

//-(void)setStringArray:(NSArray*)value forKey(NSString*)defaultName 

-(void)setInteger:(NSInteger)value forKey:(NSString*)defaultName {
	[self setValue:[NSNumber numberWithInteger:value] forValuesKey:defaultName];
}

-(void)setFloat:(float)value forKey:(NSString*)defaultName {
	[self setValue:[NSNumber numberWithFloat:value] forValuesKey:defaultName];
}

-(void)setDouble:(double)value forKey:(NSString*)defaultName {
	[self setValue:[NSNumber numberWithDouble:value] forValuesKey:defaultName];
}

-(void)setBool:(BOOL)value forKey:(NSString*)defaultName {
	[self setValue:[NSNumber numberWithBool:value] forValuesKey:defaultName];
}

@end

CF_EXTERN_C_BEGIN

NSString* valuesKeyPath(NSString* key) {
	return [@"values." stringByAppendingString:key];
}

CF_EXTERN_C_END

@implementation NSObject (N2ValuesBinding)

-(id)valueForValuesKey:(NSString*)keyPath {
	return [self valueForKeyPath:valuesKeyPath(keyPath)];
}

-(void)setValue:(id)value forValuesKey:(NSString*)keyPath {
	[self setValue:value forKeyPath:valuesKeyPath(keyPath)];
}

-(void)bind:(NSString*)binding toObject:(id)observable withValuesKey:(NSString*)key options:(NSDictionary*)options {
	[self bind:binding toObject:observable withKeyPath:valuesKeyPath(key) options:options];
}

-(void)addObserver:(NSObject*)observer forValuesKey:(NSString*)key options:(NSKeyValueObservingOptions)options context:(void*)context {
	[self addObserver:observer forKeyPath:valuesKeyPath(key) options:options context:context];
}

-(void)removeObserver:(NSObject*)observer forValuesKey:(NSString*)key {
	[self removeObserver:observer forKeyPath:valuesKeyPath(key)];
}

@end

