//
//  BCClient.h
//  Hive
//
//  Created by Bazyli Zygan on 20.06.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "AFHTTPClient.h"

@class HIContact;

/*
 This object acts as a single gateway to BitcoinKit and Tor, handles sending bitcoins, managing wallets etc.
 */

@interface BCClient : AFHTTPClient

@property (nonatomic, readonly, getter = unreadTransactions) NSUInteger unreadTransactions;
@property (nonatomic, readonly) uint64 balance;
@property (nonatomic, strong) NSString *walletHash;
@property (nonatomic, readonly, getter = isRunning) BOOL isRunning;
@property (nonatomic, assign, setter = setCheckInterval:) NSUInteger checkInterval;

+ (BCClient *)sharedClient;

- (void)shutdown;
- (void)updateNotifications;

- (void)exchangeRateFor:(uint64)btcs forCurrency:(NSString *)currency completion:(void(^)(uint64 value))completion;

- (void)sendBitcoins:(uint64)amount
              toHash:(NSString *)hash
          completion:(void(^)(BOOL success, NSString *transactionId))completion;

- (void)sendBitcoins:(uint64)amount
           toContact:(HIContact *)contact
          completion:(void(^)(BOOL success, NSString *transactionId))completion;

- (NSDictionary *)transactionDefinitionWithHash:(NSString *)hash;

- (BOOL)backupWalletAtURL:(NSURL *)backupURL;
- (BOOL)importWalletFromURL:(NSURL *)walletURL;

@end
