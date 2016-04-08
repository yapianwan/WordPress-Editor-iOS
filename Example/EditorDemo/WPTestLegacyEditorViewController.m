#import "WPTestLegacyEditorViewController.h"

@import Photos;
@import AVFoundation;
@import MobileCoreServices;

@interface WPTestLegacyEditorViewController () <WPLegacyEditorViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property(nonatomic, strong) NSMutableDictionary *mediaAdded;
@property(nonatomic, strong) NSString *selectedMediaID;
@property(nonatomic, strong) NSCache *videoPressCache;

@end

@implementation WPTestLegacyEditorViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.delegate = self;
    self.navigationItem.rightBarButtonItems = @[
                                                [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_preview"]
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(previewAction)],
                                                [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_options"]
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(previewOptions)]
                                                ];
    self.mediaAdded = [NSMutableDictionary dictionary];
    self.videoPressCache = [[NSCache alloc] init];
}

#pragma mark - Navigation Bar

- (void)previewAction
{

}

- (void)previewOptions
{

}

- (void)editorDidPressMedia:(WPLegacyEditorViewController *)editorController
{
    [self showPhotoPicker];
}

- (void)showPhotoPicker
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.navigationBar.translucent = NO;
    picker.modalPresentationStyle = UIModalPresentationCurrentContext;
    picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:picker.sourceType];
    [self.navigationController presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
        [self addAssetToContent:assetURL];
    }];

}

- (void)addImageDataToContent:(NSData *)imageData
{
    NSString *imageID = [[NSUUID UUID] UUIDString];
    NSString *path = [NSString stringWithFormat:@"%@/%@.jpg", NSTemporaryDirectory(), imageID];
    [imageData writeToFile:path atomically:YES];

    NSString *imgHTML = [NSString stringWithFormat:@"<img src=\"%@\" alt=\"%@\" class=\"alignnone size-full\" />", path, @"text"];

    self.bodyText = [NSString stringWithFormat:@"%@%@", self.bodyText, imgHTML];
}

- (void)addImageAssetToContent:(PHAsset *)asset
{
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.synchronous = NO;
    options.networkAccessAllowed = YES;
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;

    [[PHImageManager defaultManager] requestImageDataForAsset:asset
                                                      options:options
                                                resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                                                    [self addImageDataToContent:imageData];
                                                }];
}

- (void)addVideoAssetToContent:(PHAsset *)originalAsset
{
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.synchronous = NO;
    options.networkAccessAllowed = YES;
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    NSString *videoID = [[NSUUID UUID] UUIDString];
    NSString *videoPath = [NSString stringWithFormat:@"%@%@.mov", NSTemporaryDirectory(), videoID];
    PHVideoRequestOptions *videoOptions = [PHVideoRequestOptions new];
    videoOptions.networkAccessAllowed = YES;    
    [[PHImageManager defaultManager] requestExportSessionForVideo:originalAsset
                                                          options:videoOptions
                                                     exportPreset:AVAssetExportPresetPassthrough
                                                    resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
                                                        exportSession.outputFileType = (__bridge NSString*)kUTTypeQuickTimeMovie;
                                                        exportSession.shouldOptimizeForNetworkUse = YES;
                                                        exportSession.outputURL = [NSURL fileURLWithPath:videoPath];
                                                        [exportSession exportAsynchronouslyWithCompletionHandler:^{
                                                            if (exportSession.status != AVAssetExportSessionStatusCompleted) {
                                                                return;
                                                            }
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                NSString *videoHTML = [NSString stringWithFormat:@"<video src=\"%@\" alt=\"%@\" class=\"alignnone size-full\" />",videoPath, @"text"];

                                                                self.bodyText = [NSString stringWithFormat:@"%@%@", self.bodyText, videoHTML];
                                                            });
                                                        }];
                                                        
                                                    }];
}

- (void)addAssetToContent:(NSURL *)assetURL
{
    PHFetchResult *assets = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
    if (assets.count < 1) {
        return;
    }
    PHAsset *asset = [assets firstObject];
    
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        [self addVideoAssetToContent:asset];
    } if (asset.mediaType == PHAssetMediaTypeImage) {
        [self addImageAssetToContent:asset];
    }
}

@end
