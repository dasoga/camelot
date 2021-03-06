/*
 Copyright (c) 2015, Apple Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ORKTextFieldView.h"
#import "ORKSkin.h"
#import "ORKAccessibility.h"


@implementation ORKCaretOptionalTextField

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    _hitClearButton = NO;
    if ([self allowsSelection]) {
        return [super hitTest:point withEvent:event];
    } else {
        // Make exception for clear button, which is hittable
        if ( CGRectContainsPoint([self clearButtonRectForBounds:self.bounds], point)) {
            UIView *hitView = [super hitTest:point withEvent:event];
            // Where we are using a picker for date, time interval, and choice
            // Turn on flag to avoid bring up the keyboard when the field is not active.
            _hitClearButton = [hitView isKindOfClass:[UIButton class]];
            return hitView;
        }
        return nil;
    }
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    if (_allowsSelection) {
        return [super caretRectForPosition:position];
    } else {
        return CGRectZero;
    }
}

@end


@implementation ORKUnitTextField {
    NSString *_managedPlaceholder;
    
    NSString *_unitWithNumber;
    NSString *_unitWithPlaceholder;
 
    UIColor *_unitRegularColor;
    UIColor *_unitActiveColor;
    
    UIColor *_savedSuffixColor;
    NSString *_savedSuffixText;
    
    UILabel *_suffixLabel;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(textFieldDidBeginEditing:) name:UITextFieldTextDidBeginEditingNotification object:self];
        [[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(textFieldDidEndEditing:) name:UITextFieldTextDidEndEditingNotification object:self];
        [[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(textFieldDidChange:) name:UITextFieldTextDidChangeNotification object:self];
        
    }
    return self;
}

- (id)ork_createTextLabelWithTextColor:(UIColor *)textColor {
    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    textLabel.font = [UIFont systemFontOfSize:17];
    [textLabel setOpaque:NO];
    [textLabel setBackgroundColor:nil];
    textLabel.contentMode = UIViewContentModeRedraw;
    if (textColor != nil) {
        textLabel.textColor = textColor;
    }
    return textLabel;
}

- (void)ork_setSuffix:(NSString *)suffix withColor:(UIColor *)color {
    if (_suffixLabel) {
        [_suffixLabel removeFromSuperview];
        _suffixLabel = nil;
        [self setNeedsLayout];
    }
    if ([suffix length] == 0) {
        return;
    }
    _suffixLabel = [self ork_createTextLabelWithTextColor:color ?: [UIColor grayColor]];
    _suffixLabel.text = suffix;
    _suffixLabel.font = self.font;
    _suffixLabel.textAlignment = NSTextAlignmentLeft;
    _suffixLabel.userInteractionEnabled = NO;
    _suffixLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    // re-layout to position the suffix
    [self setNeedsLayout];
}

- (void)ork_updateSuffix:(NSString *)suffix {
    if (!_suffixLabel) {
        [self ork_setSuffix:suffix withColor:nil];
    } else {
        _suffixLabel.text = suffix;
        [self setNeedsLayout];
    }
}

- (void)ork_updateSuffix:(NSString *)suffix withColor:(UIColor *)color {
    if (NO == [color isEqual:_savedSuffixColor]) {
        if (suffix != nil) {
            _savedSuffixColor = color;
        }
        _savedSuffixText = suffix;
        [self ork_setSuffix:suffix withColor:color];
        return;
    }
    
    if (NO == [suffix isEqualToString:_savedSuffixText]) {
        _savedSuffixText = suffix;
        [self ork_updateSuffix:suffix];
    }
}

- (void)setManageUnitAndPlaceholder:(BOOL)manageUnitAndPlaceholder {
    _manageUnitAndPlaceholder = manageUnitAndPlaceholder;
    [self updateManagedUnitAndPlaceholder];
}

- (void)setPlaceholder:(NSString *)placeholder {
    _managedPlaceholder = placeholder;
    [self updateManagedUnitAndPlaceholder];
}

- (void)ork_setPlaceholder:(NSString *)placeholder {
    [super setPlaceholder:placeholder];
}

- (void)setUnit:(NSString *)unit {
    _unit = unit;
    
    if (_unit.length > 0) {
        _unitWithPlaceholder = [NSString stringWithFormat:@"    %@",unit];
        _unitWithNumber = [NSString stringWithFormat:@" %@",unit];
        _unitRegularColor = [UIColor blackColor];
        _unitActiveColor = [UIColor ork_midGrayTintColor];
    } else {
        _unitWithPlaceholder = nil;
        _unitWithNumber = nil;
    }
    
    [self updateManagedUnitAndPlaceholder];
}

- (void)updateManagedUnitAndPlaceholder {
    if (_manageUnitAndPlaceholder) {
        BOOL editing = [self isEditing];
        
        if (editing) {
            [self ork_setPlaceholder: nil];
            [self ork_updateSuffix:_unitWithNumber withColor:_unitActiveColor];
        } else {
            if (_managedPlaceholder.length > 0) {
                [self ork_setPlaceholder: (self.text.length == 0)? _managedPlaceholder : nil];
                NSString *unit = (self.text.length == 0)? _unitWithPlaceholder : _unitWithNumber;
                [self ork_updateSuffix:unit withColor:_unitRegularColor];
            } else {
                if (self.text.length > 0) {
                    [self ork_setPlaceholder:nil];
                    [self ork_updateSuffix:_unitWithNumber withColor:_unitRegularColor];
                } else {
                    [self ork_setPlaceholder: _unit];
                    [self ork_updateSuffix:nil withColor:_unitRegularColor];
                }
            }
        }
    } else {
        // remove unit string
        if (_savedSuffixText.length > 0) {
            [self ork_updateSuffix:nil withColor:nil];
        }
        // put back unit string
        if ([self.placeholder isEqualToString: _managedPlaceholder] == NO) {
            [self ork_setPlaceholder:_managedPlaceholder];
        }
    }
    [self invalidateIntrinsicContentSize];
}

- (void)textFieldDidBeginEditing:(NSNotification *)notification {
    [self updateManagedUnitAndPlaceholder];
}

- (void)textFieldDidEndEditing:(NSNotification *)notification {
    [self updateManagedUnitAndPlaceholder];
    
}

- (void)textFieldDidChange:(NSNotification *)notification {
    [self updateManagedUnitAndPlaceholder];
}

- (void)setText:(NSString *)text {
    [super setText:text];
    [self updateManagedUnitAndPlaceholder];
}

- (BOOL)isPlaceholderVisible {
    BOOL editing = [self isEditing];
    return (! editing) && ([[self placeholder] length] > 0);
}

- (CGFloat)suffixWidthForBounds:(CGRect)bounds {
    CGFloat suffixWidth = [_suffixLabel.text sizeWithAttributes:@{NSFontAttributeName: _suffixLabel.font}].width;
    suffixWidth = MIN(suffixWidth, bounds.size.width / 2);
    return suffixWidth;
}

static const UIEdgeInsets paddingGuess = (UIEdgeInsets){.left = 6, .right=6};

- (CGRect)textRectForBounds:(CGRect)bounds {
    CGRect textRect = [super textRectForBounds:bounds];
    
    // Leave room for the suffix label
    if ([_suffixLabel.text length]) {
        CGFloat suffixWidth = [self suffixWidthForBounds:bounds];
        if (suffixWidth > 0) {
            suffixWidth += paddingGuess.right;
        }
        textRect.size.width = MAX(0, textRect.size.width - suffixWidth);
    }
    return textRect;
}


- (CGRect)editingRectForBounds:(CGRect)bounds {
    CGRect r = [super editingRectForBounds:bounds];
    
    // Leave room for the suffix label
    if ([_suffixLabel.text length]) {
        CGFloat suffixWidth = [self suffixWidthForBounds:bounds];
        if (suffixWidth > 0) {
            suffixWidth += paddingGuess.right;
        }
        r.size.width = MAX(0, r.size.width - suffixWidth);
    }
    
    return r;
}

- (CGRect)ork_suffixFrame {
    // Get the text currently 'in' the edit field
    NSString *textToMeasure = [self isPlaceholderVisible] ? [self placeholder] : self.text;
    CGSize sizeOfText = [textToMeasure sizeWithAttributes:[self defaultTextAttributes]];
    
    // Get the maximum size of the actual editable area (taking into account prefix/suffix/views/clear button
    CGRect textFrame = [self textRectForBounds:[self bounds]];
    
    // Work out the size of our suffix frame
    CGRect suffixFrame = [super placeholderRectForBounds:[self bounds]];
    suffixFrame.size.width = [self suffixWidthForBounds:[self bounds]];
    
    // Take padding into account
    CGFloat xMaximum = CGRectGetMaxX(textFrame);
    if (sizeOfText.width < (textFrame.size.width - (paddingGuess.left + paddingGuess.right))) {
        // Adjust the rectangle to include the padding
        textFrame.origin.x += paddingGuess.left;
        textFrame.size.width -= paddingGuess.left + paddingGuess.right;
    } else {
        // Cover the fringe case where the padding is not applied, but the field editor has not scrolled, so the prefix/suffix could
        // overlap the text slightly.
        sizeOfText.width += paddingGuess.left + paddingGuess.right;
    }
    
    // Calculate position for alignment
    CGFloat xOffset = CGRectGetMinX(textFrame) + sizeOfText.width;
    
    // Make sure it can't escape out the right of the view
    suffixFrame.origin.x = MIN(xOffset, xMaximum);
    return suffixFrame;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_suffixLabel) {
        [self addSubview:_suffixLabel];
        _suffixLabel.frame = [self ork_suffixFrame];
        [_suffixLabel setNeedsDisplay];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]  removeObserver:self];
}

#pragma mark Accessibility

- (NSString *)accessibilityValue {
    if (self.text.length > 0) {
        return ORKAccessibilityStringForVariables(self.text, _unitWithNumber);
    }
    
    NSString *placeholder = _managedPlaceholder ?: self.placeholder;
    return ORKAccessibilityStringForVariables(placeholder, _unitWithNumber);
}

@end


@implementation ORKTextFieldView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _textField = [[ORKUnitTextField alloc] init];
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        [self addSubview:_textField];
    }
    return self;
}

- (void)updateConstraints {
    [super updateConstraints];
    
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *views = NSDictionaryOfVariableBindings(_textField);
    
    [self addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_textField]|"
                                                                  options:NSLayoutFormatDirectionLeadingToTrailing
                                                                  metrics:nil
                                                                    views:views]];
    
    [self addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_textField]|"
                                                                  options:NSLayoutFormatDirectionLeadingToTrailing
                                                                  metrics:nil
                                                                    views:views]];
    
    // Ask to fill the available horizontal space
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:_textField
                                                         attribute:NSLayoutAttributeWidth
                                                         relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:10000];
    constraint.priority = UILayoutPriorityDefaultLow;
    [self addConstraint:constraint];
    
}


@end
