//
//  FileOperationsViewController.m
//  DLSFTPClient
//
//  Created by Dan Leehr on 9/3/12.
//  Copyright (c) 2012 Dan Leehr. All rights reserved.
//

#import "FileOperationsViewController.h"
#import "DLSFTPFile.h"
#import "DLSFTPConnection.h"

typedef enum {
      eAlertViewTypeDelete
    , eAlertViewTypeRename
} eAlertViewType;

@interface FileOperationsViewController () <UIAlertViewDelegate>

@property (nonatomic, weak) DLSFTPConnection *connection;
@property (nonatomic, strong) DLSFTPFile *file; // strong because on rename it gets replaced

@end

@implementation FileOperationsViewController

- (id)initWithFile:(DLSFTPFile *)file
        connection:(DLSFTPConnection *)connection {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.file = file;
        self.connection = connection;
        self.title = [file filename];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    CGFloat buttonHeight = 44.0f;
    CGFloat padding = 10.0f;
    /* -[  ]-[  ]-[  ]- */
    CGFloat buttonWidth = roundf((CGRectGetWidth(self.view.bounds) - (padding * 4.0f)) / 3.0f);

    /* show permissions */
    // 3x3

    UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    deleteButton.frame = CGRectMake(  CGRectGetMinX(self.view.bounds) + padding
                                    , CGRectGetMinY(self.view.bounds) + padding
                                    , buttonWidth
                                    , buttonHeight);
    [deleteButton setTitle:@"Delete" forState:UIControlStateNormal];
    [deleteButton addTarget:self
                     action:@selector(deleteTapped:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:deleteButton];

    UIButton *renameButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    renameButton.frame = CGRectMake(  CGRectGetMaxX(deleteButton.frame) + padding
                                    , CGRectGetMinY(self.view.bounds) + padding
                                    , buttonWidth
                                    , buttonHeight);
    [renameButton setTitle:@"Rename" forState:UIControlStateNormal];
    [renameButton addTarget:self
                     action:@selector(renameTapped:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:renameButton];

    UIButton *moveButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    moveButton.frame = CGRectMake(  CGRectGetMaxX(renameButton.frame) + padding
                                    , CGRectGetMinY(self.view.bounds) + padding
                                    , buttonWidth
                                    , buttonHeight);
    [moveButton setTitle:@"Move" forState:UIControlStateNormal];
    [moveButton addTarget:self
                     action:@selector(moveTapped:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:moveButton];

}

- (void)deleteTapped:(id)sender {
    NSString *confrimationText = [NSString stringWithFormat:@"Are you sure you want to delete %@", self.file.filename];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Delete"
                                                        message:confrimationText
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Delete", nil];
    alertView.tag = eAlertViewTypeDelete;
    [alertView show];
}

- (void)renameTapped:(id)sender {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Rename"
                                                        message:@"Enter the new name:"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Create", nil];

    alertView.tag = eAlertViewTypeRename;
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *alertViewTextField = [alertView textFieldAtIndex:0];
    alertViewTextField.keyboardType = UIKeyboardTypeASCIICapable;
    alertViewTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    alertViewTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    alertViewTextField.text = [self.file filename];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        // cancelled, ignore
        return;
    }
    // check the tag
    switch (alertView.tag) {
        case eAlertViewTypeRename: {
            UITextField *textField = [alertView textFieldAtIndex:0];
            NSString *newFilename = [textField.text lastPathComponent];
            [self renameConfirmedWithNewFilename:newFilename];
            break;
        }
        case eAlertViewTypeDelete: {
            [self deleteConfirmed];
            break;
        }
        default:
            break;
    }
}

- (void)renameConfirmedWithNewFilename:(NSString *)text {
    __weak FileOperationsViewController *weakSelf = self;
    DLSFTPClientFileMetadataSuccessBlock successBlock = ^(DLSFTPFile *renamedItem) {
        weakSelf.file = renamedItem;
        weakSelf.title = [renamedItem filename];
    };

    DLSFTPClientFailureBlock failureBlock = ^(NSError *error) {
        NSString *title = [NSString stringWithFormat:@"%@ Error: %d", error.domain, error.code];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    };

    NSString *newPath = [[self.file.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:text];
    [self.connection renameOrMoveItemAtRemotePath:self.file.path
                                      withNewPath:newPath
                                     successBlock:successBlock
                                     failureBlock:failureBlock];
    
}

- (void)deleteConfirmed {
    __weak FileOperationsViewController *weakSelf = self;
    DLSFTPClientSuccessBlock successBlock = ^{
        [weakSelf.navigationController popViewControllerAnimated:YES];
    };

    DLSFTPClientFailureBlock failureBlock = ^(NSError *error) {
        NSString *title = [NSString stringWithFormat:@"%@ Error: %d", error.domain, error.code];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    };

    [self.connection removeItemAtPath:self.file.path
                         successBlock:successBlock
                         failureBlock:failureBlock];
}



- (void)moveTapped:(id)sender {
    // push a view controller to pick the new location
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Move not yet implemented in UI"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];

}

@end
