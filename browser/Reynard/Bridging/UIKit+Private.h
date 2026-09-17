//
//  UIKit+Private.h
//  Reynard
//
//  Created by Minh Ton on 10/3/26.
//

#import <UIKit/UIKit.h>

@interface UIMenuElement (ReaderSettings)
@property(nonatomic, copy) NSAttributedString *attributedTitle;
@end

API_AVAILABLE(ios(15.0))
@interface UISheetPresentationControllerDetent (ReaderSettings)
+ (instancetype)_detentWithIdentifier:(NSString *)identifier
                             constant:(double)constant;
@end
