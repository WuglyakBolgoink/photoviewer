/********* PhotoViewer.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface PhotoViewer : CDVPlugin <UIDocumentInteractionControllerDelegate> {
  // Member variables go here.
}

@property (nonatomic, strong) UIDocumentInteractionController *docInteractionController;
@property (nonatomic, strong) NSMutableArray *documentURLs;

- (void)show:(CDVInvokedUrlCommand*)command;
@end

@implementation PhotoViewer

- (void)setupDocumentControllerWithURL:(NSURL *)url andTitle:(NSString *)title
{
    if (self.docInteractionController == nil) {
        self.docInteractionController = [UIDocumentInteractionController interactionControllerWithURL:url];
        self.docInteractionController.name = title;
        self.docInteractionController.delegate = self;
    } else {
        self.docInteractionController.name = title;
        self.docInteractionController.URL = url;
    }
}

- (UIDocumentInteractionController *) setupControllerWithURL: (NSURL*) fileURL
                                               usingDelegate: (id <UIDocumentInteractionControllerDelegate>) interactionDelegate {

    UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL: fileURL];
    interactionController.delegate = interactionDelegate;

    return interactionController;
}

- (UIViewController *) documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *) controller {
    return self.viewController;
}

- (void)show:(CDVInvokedUrlCommand*)command
{
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:self.viewController.view.frame];
    [activityIndicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [activityIndicator.layer setBackgroundColor:[[UIColor colorWithWhite:0.0 alpha:0.30] CGColor]];
    CGPoint center = self.viewController.view.center;
    activityIndicator.center = center;
    [self.viewController.view addSubview:activityIndicator];

    [activityIndicator startAnimating];


    CDVPluginResult* pluginResult = nil;
    NSString* url = [command.arguments objectAtIndex:0];
    NSString* title = [command.arguments objectAtIndex:1];

    if (url != nil && [url length] > 0)
    {
        [self.commandDelegate runInBackground:^{
            self.documentURLs = [NSMutableArray array];

            @try {
                NSURL *URL = [self localFileURLForImage:url];

                if (URL)
                {
                    [self.documentURLs addObject:URL];
                    [self setupDocumentControllerWithURL:URL andTitle:title];
                }
            }
            @catch (NSException * e)
            {
                NSLog(@"Exception: %@", e);
            }

            double delayInSeconds = 0.1;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [activityIndicator stopAnimating];
                [self.docInteractionController presentPreviewAnimated:YES];
            });
        }];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSURL *)localFileURLForImage:(NSString *)image
{
    NSString* imagePath = [image stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
    NSLog(@"0. imagePath %@", imagePath);

    // save this image to a temp folder
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSLog(@"1. tmpDirURL %@", tmpDirURL);

    NSString *filename = [[NSUUID UUID] UUIDString];
    NSLog(@"2. filename %@", filename);

    NSURL *fileURL = [NSURL URLWithString:imagePath];

        @try
        {
            NSNumber *fileSizeValue = nil;
            [fileURL getResourceValue:&fileSizeValue
                               forKey:NSURLFileSizeKey
                                error:nil];

            NSLog(@"0. Image size fileSizeValue %i", fileSizeValue);
        }
        @catch (NSException * e)
        {
            NSLog(@"0. Can not get filesize");
        }

    if ([fileURL isFileReferenceURL]) {
        NSLog(@"3. fileURL is isFileReferenceURL -> return fileURL");

        return fileURL;
    }

    NSLog(@"4. fileURL not isFileReferenceURL.");

    NSData *data = [NSData dataWithContentsOfURL:fileURL];

    NSLog(@"Match data equals empty nsdata? %@",[data length] == 0 ? @"YES" : @"NO");

    if( data && [data length] > 0 ) {
        NSLog(@"5. Data exist");

        @try {
            fileURL = [[tmpDirURL URLByAppendingPathComponent:filename] URLByAppendingPathExtension:[self contentTypeForImageData:data]];
            NSLog(@"7. fileURL %@", fileURL);

            NSLog(@"10. Use NSFileManager to open file");
            [[NSFileManager defaultManager] createFileAtPath:[fileURL path] contents:data attributes:nil];

            return fileURL;
        }
        @catch (NSException * e) {
            NSLog(@"8. Error: fileURL[%@] can not be open!!!", filename);
            NSLog(@"Exception: %@", e);
        }

        return nil;
    } else {
        NSLog(@"9. Data not exist!");
        return nil;
    }
}

- (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];

    switch (c) {
        case 0xFF:
            NSLog(@"6. contentTypeForImageData: %02x - %@", c, @"jpeg");
            return @"jpeg";
        case 0x89:
            NSLog(@"6. contentTypeForImageData: %02x - %@", c, @"png");
            return @"png";
        case 0x47:
            NSLog(@"6. contentTypeForImageData: %02x - %@", c, @"gif");
            return @"gif";
        case 0x49:
        case 0x4D:
            NSLog(@"6. contentTypeForImageData: %02x - %@", c, @"tiff");
            return @"tiff";
        default:
            NSLog(@"6. ERROR! contentTypeForImageData: %02x - UNKOWN TYPE", c);
            return nil;
    }
    return nil;
}

@end
