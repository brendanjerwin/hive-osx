//
//  HISendBitcoinsWindowController.m
//  Hive
//
//  Created by Jakub Suder on 05.09.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "BCClient.h"
#import "HIAddress.h"
#import "HIButtonWithSpinner.h"
#import "HIContactAutocompleteWindowController.h"
#import "HISendBitcoinsWindowController.h"

NSString * const HISendBitcoinsWindowDidClose = @"HISendBitcoinsWindowDidClose";
NSString * const HISendBitcoinsWindowSuccessKey = @"success";

@interface HISendBitcoinsWindowController () {
    HIContact *_contact;
    HIContactAutocompleteWindowController *_autocompleteController;
    NSString *_hashAddress;
    double _amount;
}

@end

@implementation HISendBitcoinsWindowController

- (id)init
{
    self = [super initWithWindowNibName:@"HISendBitcoinsWindowController"];

    if (self)
    {
        _amount = -1;
    }

    return self;
}

- (id)initWithContact:(HIContact *)contact {
    self = [self init];

    if (self) {
        _contact = contact;
    }

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window center];

    if (_contact)
    {
        HIAddress *address = [_contact.addresses anyObject];
        [self selectContact:_contact address:address];
    }
    else if (_hashAddress)
    {
        [self setHashAddress:_hashAddress];
    }
    else
    {
        [self setHashAddress:@""];

        self.addressLabel.stringValue = NSLocalizedString(@"or choose from the list", @"Autocomplete dropdown prompt");
    }

    self.photoView.layer.cornerRadius = 5.0;
    self.photoView.layer.masksToBounds = YES;

    self.wrapper.layer.cornerRadius = 5.0;

    if (_amount <= 0)
    {
        self.amountField.stringValue = @"0";
    }
    else
    {
        [self setLockedAmount:_amount];
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    _autocompleteController = nil;
}

- (void)setHashAddress:(NSString *)hash
{
    [self clearContact];

    _hashAddress = hash;
    self.nameLabel.stringValue = _hashAddress;
}

- (void)setLockedAmount:(double)amount
{
    _amount = amount;

    [self.amountField setStringValue:[self.amountField.formatter stringFromNumber:@(_amount)]];
    [self.amountField setEditable:NO];
}

- (void)clearContact
{
    _contact = nil;
    _hashAddress = nil;

    self.addressLabel.stringValue = @"";
    self.photoView.image = [NSImage imageNamed:@"avatar-empty"];
}

- (void)selectContact:(HIContact *)contact address:(HIAddress *)address
{
    _contact = contact;
    _hashAddress = address.address;

    self.nameLabel.stringValue = contact.name;
    self.addressLabel.stringValue = address ? address.addressSuffixWithCaption : @"";
    self.photoView.image = _contact.avatarImage;

    [self.window makeFirstResponder:nil];
}

- (HIContactAutocompleteWindowController *)autocompleteController
{
    if (!_autocompleteController)
    {
        _autocompleteController = [[HIContactAutocompleteWindowController alloc] init];
        _autocompleteController.delegate = self;
    }

    return _autocompleteController;
}


#pragma mark - Handling button clicks

- (void)dropdownButtonClicked:(id)sender
{
    if ([sender state] == NSOnState)
    {
        if (_contact)
        {
            [self startAutocompleteForCurrentContact];
        }
        else
        {
            [self startAutocompleteForCurrentQuery];
        }
    }
    else
    {
        [self hideAutocompleteWindow];
    }
}

- (void)cancelClicked:(id)sender
{
    [self closeAndNotifyWithSuccess:NO amount:0];
}

- (void)sendClicked:(id)sender
{
    NSNumberFormatter *formatter = self.amountField.formatter;
    NSNumber *amount = [formatter numberFromString: self.amountField.stringValue];
    uint64 satoshi = amount.doubleValue * SATOSHI;

    if (amount.floatValue == 0) {
        NSAlert *alert = [NSAlert new];

        alert.messageText = NSLocalizedString(@"Enter an amount greater than zero.",
                                              @"Sending zero bitcoin alert title");
        alert.informativeText = NSLocalizedString(@"Why would you want to send someone 0 BTC?",
                                                  @"Sending zero bitcoin alert message");

        [self showOKAlert:alert];

        return;
    }

    if (satoshi > [BCClient sharedClient].balance)
    {
        NSAlert *alert = [NSAlert new];
        
        alert.messageText = NSLocalizedString(@"Amount exceeds balance.",
                                              @"Amount exceeds balance alert title");
        alert.informativeText = NSLocalizedString(@"You cannot send more money than you own.",
                                                  @"Amount exceeds balance alert message");

        [self showOKAlert:alert];

        return;
    }

    [self.sendButton showSpinner];

    NSString *target = _hashAddress ? _hashAddress : self.nameLabel.stringValue;

    [[BCClient sharedClient] sendBitcoins:satoshi toHash:target completion:^(BOOL success, NSString *hash) {
        [self closeAndNotifyWithSuccess:YES amount:amount.doubleValue];
    }];
}

- (void)closeAndNotifyWithSuccess:(BOOL)success amount:(double)amount
{
    [self.sendButton hideSpinner];

    if (_sendCompletion)
    {
        _sendCompletion(success, amount, nil);
    }

    [self close];

    [[NSNotificationCenter defaultCenter] postNotificationName:HISendBitcoinsWindowDidClose
                                                        object:self
                                                      userInfo:@{HISendBitcoinsWindowSuccessKey: @(success)}];
}

- (void)showOKAlert:(NSAlert *)alert
{
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button title")];

    [alert beginSheetModalForWindow:self.window
                      modalDelegate:nil
                     didEndSelector:nil
                        contextInfo:NULL];
}


#pragma mark - Autocomplete

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self clearContact];
    [self startAutocompleteForCurrentQuery];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    [self hideAutocompleteWindow];
}

- (void)startAutocompleteForCurrentQuery
{
    NSString *query = self.nameLabel.stringValue;

    [self showAutocompleteWindow];
    [[self autocompleteController] searchWithQuery:query];
}

- (void)startAutocompleteForCurrentContact
{
    [self showAutocompleteWindow];
    [[self autocompleteController] searchWithContact:_contact];
}

- (void)showAutocompleteWindow
{
    NSWindow *popup = [[self autocompleteController] window];

    if (!popup.isVisible)
    {
        NSRect dialogFrame = self.window.frame;
        NSRect popupFrame = popup.frame;
        NSRect separatorFrame = [self.window.contentView convertRect:self.separator.frame
                                                            fromView:self.wrapper];

        popupFrame = NSMakeRect(dialogFrame.origin.x + separatorFrame.origin.x,
                                dialogFrame.origin.y + separatorFrame.origin.y - popupFrame.size.height,
                                separatorFrame.size.width,
                                popupFrame.size.height);

        [popup setFrame:popupFrame display:YES];
        [self.window addChildWindow:popup ordered:NSWindowAbove];
    }

    self.dropdownButton.state = NSOnState;
}

- (void)hideAutocompleteWindow
{
    [[self autocompleteController] close];

    self.dropdownButton.state = NSOffState;
}

- (void)addressSelectedInAutocomplete:(HIAddress *)address
{
    [self selectContact:address.contact address:address];
    [self hideAutocompleteWindow];
}

@end