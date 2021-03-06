//
//  ViewController.m
//  Discrete Calculator
//
//  Created by Theodore Dubois on 7/23/18.
//  Copyright © 2018 Theodore Dubois. All rights reserved.
//

#include <CoreText/CoreText.h>
#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *displayLabel;
@property (weak, nonatomic) IBOutlet UILabel *modDisplay;
@property (weak, nonatomic) IBOutlet UIButton *expButton;
@property (weak, nonatomic) IBOutlet UIButton *inverseButton;
@property NSNumberFormatter *formatter;

@property (nonatomic) CalcNumber accumulator;
@property (nonatomic) CalcOperator op;
@property (nonatomic) CalcNumber operand;
@property (nonatomic) CalcNumber modulus;
@property (nonatomic) BOOL accumulatorShowing;

@property BOOL rage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"modulus": @10}];
    if ([defaults boolForKey:@"we ded"]) {
        self.rage = YES;
        [defaults setBool:NO forKey:@"we ded"];
    }
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIMenuControllerDidHideMenuNotification object:[UIMenuController sharedMenuController] queue:nil usingBlock:^(NSNotification *n) {
        [self.displayLabel resignFirstResponder];
    }];
    
    // set the title on the x^y button to actually have a superscript
    CGFloat offset = self.expButton.titleLabel.font.pointSize / 2;
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:@"xy"];
    [title addAttribute:(NSString *) kCTSuperscriptAttributeName value:@1 range:NSMakeRange(1, 1)];
    [title addAttribute:NSBaselineOffsetAttributeName value:@(-offset) range:NSMakeRange(1, 1)];
    [self.expButton setAttributedTitle:title forState:UIControlStateNormal];
    
    // and the 1/x button
    // jk I couldn't get it to work
//    title = [[NSMutableAttributedString alloc] initWithString:@"1/x"];
//    [title addAttribute:(NSString *) kCTSuperscriptAttributeName value:@1 range:NSMakeRange(0, 1)];
//    [title addAttribute:(NSString *) kCTSuperscriptAttributeName value:@-1 range:NSMakeRange(2, 1)];
//    [title addAttribute:NSBaselineOffsetAttributeName value:@(-16) range:NSMakeRange(0, 1)];
//    [title addAttribute:NSBaselineOffsetAttributeName value:@(16) range:NSMakeRange(2, 1)];
//    [self.inverseButton setAttributedTitle:title forState:UIControlStateNormal];
    
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.usesGroupingSeparator = YES;
    formatter.maximumFractionDigits = 0;
    formatter.allowsFloats = NO;
    self.formatter = formatter;
    
    self.accumulator = 0;
    self.op = OpNone;
    self.operand = 0;
    self.modulus = [[defaults objectForKey:@"modulus"] unsignedLongLongValue];
    
    [self showAccumulator];
}

- (void)viewDidAppear:(BOOL)animated {
    if (self.rage) {
        [self performSegueWithIdentifier:@"rage" sender:nil];
        self.rage = NO;
    }
}

- (IBAction)back:(UIStoryboardSegue *)segue {
    // this is stupid
}

- (IBAction)modTap:(id)sender {
    [self.displayLabel resignFirstResponder]; // this is also stupid
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Set modulus"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.returnKeyType = UIReturnKeyDone;
        field.text = [[NSNumber numberWithUnsignedLongLong:self.modulus] stringValue];
        field.delegate = self;
    }];
    [alert addAction:
     [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields[0].text;
        if (text.length == 0)
            return;
        NSNumber *number = [self.formatter numberFromString:text];
        if (number.unsignedLongLongValue != 0) {
            self.modulus = number.unsignedLongLongValue;
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"wot?"
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"wot" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)textFieldDidBeginEditing:(UITextField *)field {
    field.selectedTextRange = [field textRangeFromPosition:field.beginningOfDocument toPosition:field.endOfDocument];
}

- (void)showNumber:(CalcNumber)number {
    if (number == CALC_ERR) {
        self.displayLabel.text = @"Error";
        return;
    }
    self.displayLabel.text = [self.formatter stringFromNumber:[NSNumber numberWithUnsignedLongLong:number]];
}

- (void)showAccumulator {
    [self showNumber:self.accumulator];
    self.accumulatorShowing = YES;
}
- (void)showOperand {
    [self showNumber:self.operand];
    self.accumulatorShowing = NO;
}

- (void)reset {
    self.accumulator = 0;
    self.op = OpNone;
    self.operand = 0;
    [self showOperand];
}
- (IBAction)clearTap:(id)sender {
    [self reset];
}

- (IBAction)operatorTap:(UIButton *)sender {
    [self accumulate];
    self.op = sender.tag;
    self.operand = 0;
    [self showOperand];
}

- (IBAction)unaryTap:(UIButton *)sender {
    if (!self.accumulatorShowing)
        [self accumulate];
    if (sender.tag == 1) {
        self.accumulator = self.modulus - self.accumulator;
    } else if (sender.tag == 2) {
        self.accumulator = ModInverse(self.accumulator, self.modulus);
    }
    [self showAccumulator];
}

- (IBAction)equalsTap:(id)sender {
    [self accumulate];
}

static CalcNumber ModInverse(CalcNumber a, CalcNumber n) {
    long long t = 0, newt = 1, r = n, newr = a;
    long long tmp;
    while (newr != 0) {
        CalcNumber quotient = r / newr;
        tmp = t; t = newt; newt = tmp - quotient * newt;
        tmp = r; r = newr; newr = tmp - quotient * newr;
    }
    if (r > 1) return CALC_ERR;
    if (t < 0) t = t + n;
    return t;
}

static CalcNumber ModPower(CalcNumber base, CalcNumber exp, CalcNumber mod) {
    CalcNumber extra = 1;
    while (exp > 1) {
        if (exp % 2 != 0) {
            extra = base * extra % mod;
        }
        base = base * base % mod;
        exp /= 2;
    }
    return base * extra % mod;
}

- (void)accumulate {
    if (self.accumulator == CALC_ERR) {
        [self showAccumulator];
        return;
    }
    
    CalcNumber inverse;
    if (self.op != OpPow)
        self.operand %= self.modulus;
    switch (self.op) {
        case OpAdd:
            self.accumulator += self.operand;
            break;
        case OpSub:
            if (self.operand > self.accumulator)
                self.accumulator = self.modulus - (self.operand - self.accumulator);
            else
                self.accumulator -= self.operand;
            break;
        case OpMul:
            self.accumulator *= self.operand;
            break;
        case OpDiv:
            inverse = ModInverse(self.operand, self.modulus);
            if (inverse == CALC_ERR)
                self.accumulator = CALC_ERR;
            else
                self.accumulator *= inverse;
            break;
        case OpPow:
            self.accumulator = ModPower(self.accumulator, self.operand, self.modulus);
            break;
        case OpNone:
            self.accumulator = self.operand;
            break;
    }
    if (self.accumulator != CALC_ERR)
        self.accumulator %= self.modulus;
    [self showAccumulator];
}

- (IBAction)numberTap:(UIButton *)sender {
    if (self.accumulatorShowing) {
        [self reset];
    }
    CalcNumber digit = sender.tag;
    self.operand = self.operand * 10 + digit;
    [self showOperand];
}

- (void)setModulus:(CalcNumber)modulus {
    _modulus = modulus;
    NSNumber *modulusNumber = [NSNumber numberWithUnsignedLongLong:modulus];
    self.modDisplay.text = [NSString stringWithFormat:@"mod %@", [self.formatter stringFromNumber:modulusNumber]];
    [[NSUserDefaults standardUserDefaults] setObject:modulusNumber forKey:@"modulus"];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (IBAction)displayModPress:(id)sender {
    CGRect textRect = [self.displayLabel textRectForBounds:self.displayLabel.bounds limitedToNumberOfLines:self.displayLabel.numberOfLines];
    [self.displayLabel becomeFirstResponder];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setTargetRect:textRect inView:self.displayLabel];
    [menuController setMenuVisible:YES animated:YES];
}

@end
