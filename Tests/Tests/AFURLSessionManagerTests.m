// AFNetworkActivityManagerTests.m
// Copyright (c) 2011–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <objc/runtime.h>

#import "AFTestCase.h"

#import "AFURLSessionManager.h"

@interface AFURLSessionManagerTests : AFTestCase
@property (readwrite, nonatomic, strong) AFURLSessionManager *foregroundManager;
@end


@implementation AFURLSessionManagerTests

- (void)setUp {
    [super setUp];
    self.foregroundManager = [[AFURLSessionManager alloc] init];
}

- (void)tearDown {
    [super tearDown];
    [self.foregroundManager invalidateSessionCancelingTasks:YES];
    self.foregroundManager = nil;
}

#pragma mark -

- (void)testUploadTasksProgressBecomesPartOfCurrentProgress {
    NSProgress *overallProgress = [NSProgress progressWithTotalUnitCount:100];

    [overallProgress becomeCurrentWithPendingUnitCount:80];
    NSProgress *uploadProgress = nil;

    [self.foregroundManager uploadTaskWithRequest:[NSURLRequest requestWithURL:self.baseURL]
                               fromData:[NSData data]
                                 progress:&uploadProgress
                        completionHandler:nil];
    [overallProgress resignCurrent];

    expect(overallProgress.fractionCompleted).to.equal(0);

    uploadProgress.totalUnitCount = 1;
    uploadProgress.completedUnitCount = 1;


    expect(overallProgress.fractionCompleted).to.equal(0.8);
}

- (void)testDownloadTasksProgressBecomesPartOfCurrentProgress {
    NSProgress *overallProgress = [NSProgress progressWithTotalUnitCount:100];

    [overallProgress becomeCurrentWithPendingUnitCount:80];
    NSProgress *downloadProgress = nil;

    [self.foregroundManager downloadTaskWithRequest:[NSURLRequest requestWithURL:self.baseURL]
                                 progress:&downloadProgress
                              destination:nil
                        completionHandler:nil];
    [overallProgress resignCurrent];

    expect(overallProgress.fractionCompleted).to.equal(0);

    downloadProgress.totalUnitCount = 1;
    downloadProgress.completedUnitCount = 1;


    expect(overallProgress.fractionCompleted).to.equal(0.8);
}

- (void)testDidResumeNotificationIsReceivedByDataTaskAfterResume {
    NSURLSessionDataTask *task = [self.foregroundManager dataTaskWithRequest:[self _delayURLRequest]
                                                 completionHandler:nil];
    [self _testResumeNotificationForTask:task];
}

- (void)testDidSuspendNotificationIsReceivedByDataTaskAfterSuspend {
    NSURLSessionDataTask *task = [self.foregroundManager dataTaskWithRequest:[self _delayURLRequest]
                                                 completionHandler:nil];
    [self _testSuspendNotificationForTask:task];
}

- (void)testDidResumeNotificationIsReceivedByUploadTaskAfterResume {
    NSURLSessionUploadTask *task = [self.foregroundManager uploadTaskWithRequest:[self _delayURLRequest]
                                                              fromData:[NSData data]
                                                              progress:nil
                                                     completionHandler:nil];
    [self _testResumeNotificationForTask:task];
}

- (void)testDidSuspendNotificationIsReceivedByUploadTaskAfterSuspend {
    NSURLSessionUploadTask *task = [self.foregroundManager uploadTaskWithRequest:[self _delayURLRequest]
                                                              fromData:[NSData data]
                                                              progress:nil
                                                     completionHandler:nil];
    [self _testSuspendNotificationForTask:task];
}

- (void)testDidResumeNotificationIsReceivedByDownloadTaskAfterResume {
    NSURLSessionDownloadTask *task = [self.foregroundManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                progress:nil
                                                             destination:nil
                                                       completionHandler:nil];
    [self _testResumeNotificationForTask:task];
}

- (void)testDidSuspendNotificationIsReceivedByDownloadTaskAfterSuspend {
    NSURLSessionDownloadTask *task = [self.foregroundManager downloadTaskWithRequest:[self _delayURLRequest]
                                                                progress:nil
                                                             destination:nil
                                                       completionHandler:nil];
    [self _testSuspendNotificationForTask:task];
}

- (void)testSwizzlingIsProperlyConfiguredForDummyClass {
    IMP originalAFResumeIMP = [self _originalAFResumeImplementation];
    IMP originalAFSuspendIMP = [self _originalAFSuspendImplementation];
    XCTAssert(originalAFResumeIMP, @"Swizzled af_resume Method Not Found");
    XCTAssert(originalAFSuspendIMP, @"Swizzled af_suspend Method Not Found");
    XCTAssertNotEqual(originalAFResumeIMP, originalAFSuspendIMP, @"af_resume and af_suspend should not be equal");
}

- (void)testSwizzlingIsWorkingAsExpectedForForegroundDataTask {
    NSURLSessionTask *task = [self.foregroundManager dataTaskWithRequest:[self _delayURLRequest]
                                             completionHandler:nil];
    [self _testSwizzlingForTask:task];
    [task cancel];
}

- (void)testSwizzlingIsWorkingAsExpectedForForegroundUpload {
    NSURLSessionTask *task = [self.foregroundManager uploadTaskWithRequest:[self _delayURLRequest]
                                                        fromData:[NSData data]
                                                        progress:nil
                                               completionHandler:nil];
    [self _testSwizzlingForTask:task];
    [task cancel];
}

- (void)testSwizzlingIsWorkingAsExpectedForForegroundDownload {
    NSURLSessionTask *task = [self.foregroundManager downloadTaskWithRequest:[self _delayURLRequest]
                                                          progress:nil
                                                       destination:nil
                                                 completionHandler:nil];
    [self _testSwizzlingForTask:task];
    [task cancel];
}

- (void)testSwizzlingIsWorkingAsExpectedForBackgroundDataTask {
    [self _testSwizzlingForTaskClass:NSClassFromString(@"__NSCFBackgroundDataTask")];
}

- (void)testSwizzlingIsWorkingAsExpectedForBackgroundUploadTask {
    [self _testSwizzlingForTaskClass:NSClassFromString(@"__NSCFBackgroundUploadTask")];
}

- (void)testSwizzlingIsWorkingAsExpectedForBackgroundDownloadTask {
    [self _testSwizzlingForTaskClass:NSClassFromString(@"__NSCFBackgroundDownloadTask")];
}

#pragma private

- (void)_testResumeNotificationForTask:(NSURLSessionTask *)task {
    [self expectationForNotification:AFNetworkingTaskDidResumeNotification
                              object:nil
                             handler:nil];
    [task resume];
    [task suspend];
    [task resume];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [task cancel];
}

- (void)_testSuspendNotificationForTask:(NSURLSessionTask *)task {
    [self expectationForNotification:AFNetworkingTaskDidSuspendNotification
                              object:nil
                             handler:nil];
    [task resume];
    [task suspend];
    [task resume];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [task cancel];
}

- (NSURLRequest *)_delayURLRequest {
    return [NSURLRequest requestWithURL:[self.baseURL URLByAppendingPathComponent:@"delay/1"]];
}

- (IMP)_implementationForTask:(NSURLSessionTask  *)task selector:(SEL)selector {
    return [self _implementationForClass:[task class] selector:selector];
}

- (IMP)_implementationForClass:(Class)class selector:(SEL)selector {
    return method_getImplementation(class_getInstanceMethod(class, selector));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
- (IMP)_originalAFResumeImplementation {
    return method_getImplementation(class_getInstanceMethod(NSClassFromString(@"_AFURLSessionTaskSwizzling"), @selector(af_resume)));
}

- (IMP)_originalAFSuspendImplementation {
    return method_getImplementation(class_getInstanceMethod(NSClassFromString(@"_AFURLSessionTaskSwizzling"), @selector(af_suspend)));
}

- (void)_testSwizzlingForTask:(NSURLSessionTask *)task {
    [self _testSwizzlingForTaskClass:[task class]];
}

- (void)_testSwizzlingForTaskClass:(Class)class {
    IMP originalAFResumeIMP = [self _originalAFResumeImplementation];
    IMP originalAFSuspendIMP = [self _originalAFSuspendImplementation];
    
    IMP taskResumeImp = [self _implementationForClass:class selector:@selector(resume)];
    IMP taskSuspendImp = [self _implementationForClass:class selector:@selector(suspend)];
    XCTAssertEqual(originalAFResumeIMP, taskResumeImp, @"resume has not been properly swizzled for %@", NSStringFromClass(class));
    XCTAssertEqual(originalAFSuspendIMP, taskSuspendImp, @"suspend has not been properly swizzled for %@", NSStringFromClass(class));
    
    IMP taskAFResumeImp = [self _implementationForClass:class selector:@selector(af_resume)];
    IMP taskAFSuspendImp = [self _implementationForClass:class selector:@selector(af_suspend)];
    XCTAssert(taskAFResumeImp != NULL, @"af_resume is nil. Something has not been been swizzled right for %@", NSStringFromClass(class));
    XCTAssertNotEqual(taskAFResumeImp, taskResumeImp, @"af_resume has not been properly swizzled for %@", NSStringFromClass(class));
    XCTAssert(taskAFSuspendImp != NULL, @"af_suspend is nil. Something has not been been swizzled right for %@", NSStringFromClass(class));
    XCTAssertNotEqual(taskAFSuspendImp, taskSuspendImp, @"af_suspend has not been properly swizzled for %@", NSStringFromClass(class));
}
#pragma clang diagnostic pop

@end
