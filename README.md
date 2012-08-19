NetRequest
==========

This is a simple iOS networking class developed by my colleague, Matt Giger and released as open source. It doesn't have all the bells and whistles as other networking classes, but is efficient and easy to understand.

I offered to maintain this for Matt, so please feel free to contribute to this.

Example of Usage
================

	#import "NetRequest.h"
	#import "JSONKit.h"
	
	- (void)loadSomething
	{
		if([NetQueue urlQueued:jsonRequestURL])
			[NetQueue cancelURL:jsonRequestURL];
			
		NSString* dataString = @"param1=7&param2=whatever";
		NetRequest* request = [NetRequest request:jsonRequestURL];
		request.method = @"POST";
		request.body = [NSData dataWithBytes:[dataString UTF8String] length:[dataString length]];
		request.parseHandler = ^(NetRequest* req)
		{
			if(!req.error)
				req.userData = [req.responseBody  objectFromJSONData];	// parse on a background thread
		};
		request.completionHandler = ^(NetRequest* req)
		{
			if(!req.error)
			{
				for(NSDictionary* dict in req.userData)
					;	// handle parsed response on the main thread
			}
		};
		[NetQueue add:request];
	}


License
==========
Created by Matt Giger
Copyright (c) 2012 EarthBrowser LLC. All rights reserved.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Contact
==========
Feel free to contact me scott@grubysolutions.com