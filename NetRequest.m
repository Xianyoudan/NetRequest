//
//  NetRequest.m
//  EarthBrowser
//
//  Created by Matt Giger
//  Copyright (c) 2012 EarthBrowser LLC. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//


#import "NetRequest.h"

static const int	_maxThreadCount		= 5;
static int			_operationCount		= 0;

@interface NetQueue()
@property (nonatomic, retain)	NSOperationQueue*			operationQueue;
+ (NetQueue*)sharedQueue;
@end


@implementation NetRequest

@synthesize url = _url;
@synthesize headers = _headers;
@synthesize method = _method;
@synthesize body = _body;
@synthesize responseBody = _responseBody;
@synthesize connection = _connection;
@synthesize error = _error;
@synthesize statusCode = _statusCode;
@synthesize userData = _userData;
@synthesize parseHandler = _parseHandler;
@synthesize completionHandler = _completionHandler;
@synthesize isFinished = _isFinished;
@synthesize isExecuting = _isExecuting;
@synthesize identifier = _identifier;

+ (NetRequest*)request:(NSString*)url
{
	NetRequest* request = [[[NetRequest alloc] init] autorelease];
	request.url = url;
	return request;
}

- (id)init
{
	if (self = [super init])
	{
		self.responseBody = [NSMutableData data];
		self.headers = [NSMutableDictionary dictionary];
		[_headers setValue:@"deflate,gzip" forKey:@"Accept-Encoding"];
		
		NSString* uagent = [[NSUserDefaults standardUserDefaults] valueForKey:@"User-Agent"];
		if([uagent length])
			[_headers setValue:uagent forKey:@"User-Agent"];
	}
	return self;
}

- (void)dealloc
{
	[_url release];
	[_headers release];
	[_method release];
	[_body release];
	[_connection release];
	[_error release];
	[_userData release];
	[_responseBody release];
	[_parseHandler release];
	[_completionHandler release];
    [_identifier release];
	
	[super dealloc];
}

- (BOOL)isConcurrent
{
	return YES;
}

- (void)start
{
	if(![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
	}
	else
	{
		[NetQueue increment];
		
		self.isExecuting = YES;
		
		if(self.isCancelled)
		{
			self.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
			[self cleanup];
		}
		else if(!self.isFinished)
		{
			NSMutableURLRequest* urlRequest = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_url]
																			cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
																		timeoutInterval:60.0] autorelease];
			for(NSString* key in _headers)
				[urlRequest setValue:[_headers objectForKey:key] forHTTPHeaderField:key];
			if (_body)
				[urlRequest setHTTPBody:_body];
			[urlRequest setHTTPMethod:_method ? _method : @"GET"];
			
			self.connection = [[[NSURLConnection alloc] initWithRequest:urlRequest delegate:self] autorelease];
			if(!_connection)
				[self cleanup];
		}
	}
}

- (void)cleanup
{
	if (_isExecuting)
	{
		if(!_isFinished)
			[NetQueue decrement];

		[self willChangeValueForKey:@"isExecuting"];
		[self willChangeValueForKey:@"isFinished"];
		_isExecuting = NO;
		_isFinished = YES;
		[self didChangeValueForKey:@"isExecuting"];
		[self didChangeValueForKey:@"isFinished"];
	}
	
	self.connection = nil;
}

- (void)cancel
{
	[_connection cancel];
	self.connection = nil;
	
	if(_isExecuting && _completionHandler)
	{
		self.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
		_completionHandler(self);
	}
	
	[self cleanup];
	
	[super cancel];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response
{
	if([response isKindOfClass:[NSHTTPURLResponse class]])
		self.statusCode = [((NSHTTPURLResponse*)response) statusCode];
	[self.responseBody setLength:0];
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)aData
{
	[_responseBody appendData:aData];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
	if(_parseHandler)
	{
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
		{
			_parseHandler(self);
			
			if(_completionHandler)
			{
				dispatch_async(dispatch_get_main_queue(),^(void)
				{
					_completionHandler(self);
					[self cleanup];
				});
			}
			else
				[self cleanup];
		});
	}
	else
	{
		if(_completionHandler)
			_completionHandler(self);
		[self cleanup];
	}
	
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error
{
	self.error = error;
	if(_completionHandler)
		_completionHandler(self);
	self.connection = nil;
}

@end




@implementation NetQueue

@synthesize operationQueue = _operationQueue;

+ (NetQueue*)sharedQueue
{
	static dispatch_once_t pred;
	static NetQueue* shared = nil;
	dispatch_once(&pred, ^{ shared = [[self alloc] initWithNumConnections:_maxThreadCount]; });
	return shared;
}

+ (NetQueue*)sharedImageQueue
{
	static dispatch_once_t pred;
	static NetQueue* sharedImage = nil;
	dispatch_once(&pred, ^{ sharedImage = [[self alloc] initWithNumConnections:_maxThreadCount]; });
	return sharedImage;
}

+ (void)increment
{
	if ([NSThread isMainThread])
	{
		_operationCount++;
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	}
	else
		[NetQueue performSelectorOnMainThread:@selector(incremement) withObject:nil waitUntilDone:NO];
	
}

+ (void)decrement
{
	if ([NSThread isMainThread])
	{
		if (--_operationCount == 0)
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}
	else
		[NetQueue performSelectorOnMainThread:@selector(decrement) withObject:nil waitUntilDone:NO];
	
}

- (void)add:(NetRequest*)request
{
	[self.operationQueue addOperation:request];
}

- (void)cancelURL:(NSString*)url
{
	for (NetRequest* request in self.operationQueue.operations)
	{
		if ([request.url isEqualToString:url])
			[request cancel];
	}
}

- (void)cancelOperationsWithIdentifier:(NSString*)identifer
{
    if (identifer != nil)
    {
        for (NetRequest* request in self.operationQueue.operations)
        {
            if (request.identifier != nil && [identifer isEqualToString:request.identifier])
                [request cancel];
        }
    }
}

- (BOOL)urlQueued:(NSString*)url
{
	for (NetRequest* request in self.operationQueue.operations)
	{
		if ([request.url isEqualToString:url])
			return YES;
	}
	return NO;
}

- (BOOL) hasOperationWithIdentifier:(NSString*)identifier
{
    if (identifier != nil)
    {
        for (NetRequest* request in self.operationQueue.operations)
        {
            if (request.identifier != nil && [request.identifier isEqualToString:identifier])
                return YES;
        }
    }
	return NO;
}

- (void)cancelAllOperations
{
	[self.operationQueue cancelAllOperations];
}

- (id)initWithNumConnections:(NSInteger)numConnections
{
	if(self = [super init])
	{
		_operationQueue = [[NSOperationQueue alloc] init];
		[_operationQueue setMaxConcurrentOperationCount:numConnections];
	}
	return self;
}

- (void)dealloc
{
	[_operationQueue cancelAllOperations];
	[_operationQueue release];
	
	[super dealloc];
}

@end
