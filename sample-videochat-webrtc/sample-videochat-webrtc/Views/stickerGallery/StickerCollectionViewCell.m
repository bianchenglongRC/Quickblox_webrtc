//
//  StickerCollectionViewCell.m
//  TUPUFaceDemo
//
//  Created by 候 金鑫 on 2017/2/8.
//  Copyright © 2017年 tupu. All rights reserved.
//

#import "StickerCollectionViewCell.h"


@interface StickerCollectionViewCell ()
@property (weak, nonatomic) IBOutlet UIImageView *stickerPreivewImg;
@end

@implementation StickerCollectionViewCell
- (void)awakeFromNib {
    [super awakeFromNib];
    [_stickerPreivewImg setImage: [UIImage imageNamed:@"sticker_preivew"]];
}

- (void)setSelectStatus:(BOOL)selectStatus {
    if (selectStatus) {
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor greenColor].CGColor;
    }
    else {
        self.layer.borderWidth = 0;
    }
    _selectStatus = selectStatus;
}
@end
