//
//  FileDownloadViewController.m
//  DLSFTPClient
//
//  Created by Dan Leehr on 8/19/12.
//  Copyright (c) 2012 Dan Leehr. All rights reserved.
//

#import "FileDownloadViewController.h"
#import "DLSFTPFile.h"
#import "DLSFTPConnection.h"
#import "DLFileSizeFormatter.h"
#import "DLDocumentsDirectoryPath.h"

@interface FileDownloadViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) DLSFTPFile *file;
@property (nonatomic, weak) DLSFTPConnection *connection;
@property (nonatomic, readwrite, assign) BOOL cancelled;
@property (nonatomic, weak) UIProgressView *progressView;
@property (nonatomic, weak) UILabel *progressLabel;

@end

@implementation FileDownloadViewController

- (id)initWithFile:(DLSFTPFile *)file connection:(DLSFTPConnection *)connection {
    if ((file == nil) || (connection == nil)) {
        self = nil;
        return self;
    }
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.file = file;
        self.connection = connection;
        self.title = file.filename;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    // file name and details
    CGFloat buttonHeight = 44.0f;
    CGFloat padding = 10.0f;
    CGFloat progressHeight = 9.0f;

    // lower rect for buttons
    UIView *lowerView = [[UIView alloc] initWithFrame:CGRectMake(  CGRectGetMinX(self.view.bounds) + padding
                                                                 , CGRectGetMaxY(self.view.bounds)
                                                                 , CGRectGetWidth(self.view.bounds) - 2.0f * padding
                                                                 , buttonHeight + progressHeight + 2.0f * padding)];
    lowerView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    lowerView.backgroundColor = [UIColor clearColor];
    lowerView.autoresizesSubviews = NO;

    // progress label
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(  CGRectGetMinX(lowerView.bounds) + padding
                                                                       , CGRectGetMinY(lowerView.bounds)
                                                                       , CGRectGetWidth(lowerView.bounds) - padding * 2.0f
                                                                       , buttonHeight)];
    progressLabel.backgroundColor = [UIColor clearColor];
    progressLabel.textAlignment = UITextAlignmentRight;
    [lowerView addSubview:progressLabel];
    self.progressLabel = _progressLabel;

    CGFloat buttonWidth = roundf((CGRectGetWidth(lowerView.bounds) - padding) / 2.0f);
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    startButton.frame = CGRectMake(  CGRectGetMinX(lowerView.bounds)
                                   , CGRectGetMaxY(progressLabel.frame) + padding
                                   , buttonWidth
                                   , buttonHeight);
    startButton.backgroundColor = [UIColor clearColor];
    [startButton setTitle:@"Download" forState:UIControlStateNormal];
    [startButton addTarget:self
                    action:@selector(startTapped:)
          forControlEvents:UIControlEventTouchUpInside
     ];

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    cancelButton.frame = CGRectMake(  CGRectGetMaxX(startButton.frame) + padding
                                    , CGRectGetMaxY(progressLabel.frame) + padding
                                    , buttonWidth
                                    , buttonHeight);
    cancelButton.backgroundColor = [UIColor clearColor];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];

    [cancelButton addTarget:self
                     action:@selector(cancelTapped:)
           forControlEvents:UIControlEventTouchUpInside
     ];

    [lowerView addSubview:startButton];
    [lowerView addSubview:cancelButton];

    // progress view
    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = CGRectMake(  CGRectGetMinX(lowerView.bounds)
                                     , CGRectGetMaxY(cancelButton.frame) + padding
                                     , CGRectGetWidth(lowerView.bounds)
                                     , progressHeight);
    progressView.backgroundColor = [UIColor greenColor];
    
    [lowerView addSubview:progressView];
    self.progressView = progressView;
    CGRect lowerViewFrame = lowerView.frame;
    lowerViewFrame.size.height = buttonHeight * 2.0f + progressHeight + 3.0f * padding;
    lowerViewFrame.origin.y = (CGRectGetMaxY(self.view.bounds) - CGRectGetHeight(lowerViewFrame));
    lowerView.frame = lowerViewFrame;

    [self.view addSubview:lowerView];

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(  CGRectGetMinX(self.view.bounds)
                                                                           , CGRectGetMinY(self.view.bounds)
                                                                           , CGRectGetWidth(self.view.bounds)
                                                                           , CGRectGetHeight(self.view.bounds) - CGRectGetHeight(lowerViewFrame))
                                                          style:UITableViewStyleGrouped];
    tableView.allowsSelection = NO;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    tableView.delegate = self;
    tableView.dataSource = self;

    [self.view addSubview:tableView];
}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.file.attributes count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    NSArray *sortedKeys = [[self.file.attributes allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSString *key = [sortedKeys objectAtIndex:indexPath.row];
    id value = [self.file.attributes objectForKey:key];
    cell.textLabel.text = key;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", value];
    return cell;
}

#pragma mark Button Handlers

- (void)startTapped:(id)sender {
    self.progressLabel.text = nil;
    self.progressView.progress = 0.0f;
    
    __weak FileDownloadViewController *weakSelf = self;
    __block UIBackgroundTaskIdentifier taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        weakSelf.cancelled = YES;
    }];
    DLSFTPClientProgressBlock progressBlock = ^BOOL(unsigned long long bytesReceived, unsigned long long bytesTotal) {
        float progress = (float)bytesReceived / (float)bytesTotal;
        weakSelf.progressView.progress = progress;
        static DLFileSizeFormatter *formatter = nil;
        if (formatter == nil) {
            formatter = [[DLFileSizeFormatter alloc] init];
        }
        NSString *receivedString = [formatter stringFromSize:bytesReceived];
        NSString *totalString = [formatter stringFromSize:bytesTotal];

        weakSelf.progressLabel.text = [NSString stringWithFormat:@"%@ / %@", receivedString, totalString];
        return (weakSelf.cancelled == NO);
    };

    DLSFTPClientFileTransferSuccessBlock successBlock = ^(DLSFTPFile *file, NSDate *startTime, NSDate *finishTime) {
        NSTimeInterval duration = round([finishTime timeIntervalSinceDate:startTime]);
        DLFileSizeFormatter *formatter = [[DLFileSizeFormatter alloc] init];
        unsigned long long rate = (file.attributes.fileSize / duration);
        NSString *rateString = [formatter stringFromSize:rate];
        weakSelf.progressLabel.text = nil;

        NSString *alertMessage = [NSString stringWithFormat:@"Downloaded %@ in %.1fs\n %@/sec", file.filename, duration, rateString];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Download completed"
                                                            message:alertMessage
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
    };

    DLSFTPClientFailureBlock failureBlock = ^(NSError *error) {
        NSString *errorString = [NSString stringWithFormat:@"Error %d", error.code];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:errorString
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
    };

    NSString *remotePath = self.file.path;
    self.cancelled = NO;
    [self.connection downloadFileAtRemotePath:remotePath
                              toLocalPath:[DLDocumentsDirectoryPath() stringByAppendingPathComponent:self.file.filename]
                            progressBlock:progressBlock
                             successBlock:successBlock
                             failureBlock:failureBlock];
}

- (void)cancelTapped:(id)sender {
    self.cancelled = YES;
}

@end
