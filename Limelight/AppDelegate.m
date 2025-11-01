//
//  AppDelegate.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "AppDelegate.h"
#import <UIKit/UIScene.h>

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

static NSOperationQueue* mainQueue;
static NSString* DB_NAME = @"Limelight_iOS.sqlite";

// 必須、新しい Scene ライフサイクルで、シーンが接続される際に呼び出されるメソッド
- (UISceneConfiguration *)application:(UIApplication *)application
           configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                              options:(UISceneConnectionOptions *)options {
    
    // Scene接続オプションからショートカットアイテムを取得
    UIApplicationShortcutItem *shortcutItem = options.shortcutItem;
    if (shortcutItem != nil) {
        // 既存のプロパティ (pcUuidToLoad) に値をセット
        self.pcUuidToLoad = (NSString*)[shortcutItem.userInfo objectForKey:@"UUID"];
    }

    // 既定の Scene 設定を返す
    return [UISceneConfiguration configurationWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

//必須
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    #if defined(UISceneDidConnectNotification)
        // 外部モニタの接続と切断を監視するための新しい Scene 通知
        // 古い UIScreenDidConnectNotification の監視コードは削除済み
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sceneDidConnect:)
                                                     name:UISceneDidConnectNotification
                                                   object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sceneDidDisconnect:)
                                                 name:UISceneDidDisconnectNotification
                                               object:nil];
    #endif
    return YES;
}

// 残しておいた方がいい。アプリ実行中にショートカットがタップされたときに呼び出される
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
}



//残しておいた方が良い
- (void)applicationDidEnterBackground:(UIApplication *)application{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


//必須
- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

//必須
- (void)saveContext{
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    if (managedObjectContext != nil) {
        [managedObjectContext performBlock:^{
            if (![managedObjectContext hasChanges]) {
                return;
            }
            NSError *error = nil;
            if (![managedObjectContext save:&error]) {
                Log(LOG_E, @"Critical database error: %@, %@", error, [error userInfo]);
            }
        }];
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
//必須
- (NSManagedObjectContext *)managedObjectContext{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
//必須
- (NSManagedObjectModel *)managedObjectModel{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
//必須
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    NSString* storeType;
    
    storeType = NSSQLiteStoreType;
    
    // We must ensure the persistent store is ready to opened
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:storeType configuration:nil URL:[self getStoreURL] options:options error:&error]) {
        // Log the error
        Log(LOG_E, @"Critical database error: %@, %@", error, [error userInfo]);
        
        // Drop the database
        [self dropDatabase];
        
        // Try again
        return [self persistentStoreCoordinator];
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
//必須
- (NSURL *)applicationDocumentsDirectory{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

//必須
- (void) dropDatabase{
    // Delete the file on disk
    [[NSFileManager defaultManager] removeItemAtURL:[self getStoreURL] error:nil];
}

//必須
- (NSURL*) getStoreURL {
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:DB_NAME];
}
	
// 必須、シーンがスクリーンに接続された時に呼び出される
- (void)sceneDidConnect:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *scene = (UIWindowScene *)notification.object;
        UIScreen *primaryScreen = [self primaryScreenContext]; // 新しいヘルパーメソッドを使用
        
        // 接続されたスクリーンがプライマリ画面と異なる場合、外部モニタだと判断する
        if (primaryScreen != nil && scene.screen != primaryScreen) {
            NSLog(@"外部モニタシーンが接続されました。");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalScreenConnected"
                                                              object:nil
                                                            userInfo:@{@"screen": scene.screen}];
        }
    }
}

// 必須、シーンがスクリーンから切断された時に呼び出される
- (void)sceneDidDisconnect:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *scene = (UIWindowScene *)notification.object;
        UIScreen *primaryScreen = [self primaryScreenContext]; // 新しいヘルパーメソッドを使用

        // 切断されたスクリーンがプライマリ画面と異なる場合、外部モニタだったと判断する
        if (primaryScreen != nil && scene.screen != primaryScreen) {
            NSLog(@"外部モニタシーンが切断されました。");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ExternalScreenDisconnected"
                                                              object:nil
                                                            userInfo:@{@"screen": scene.screen}];
        }
    }
}

//必須、プライマリ画面を検出する
- (UIScreen *)primaryScreenContext {
    // 接続されている全てのシーンから、メインのキーウィンドウを持つシーンのスクリーンを探す
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        // アクティブなシーンのウィンドウをチェック
        for (UIWindow *window in scene.windows) {
            // キーウィンドウ（通常はアプリのメインコンテンツが表示されているウィンドウ）が見つかったら、そのスクリーンを返す
            if (window.isKeyWindow) {
                return window.screen;
            }
        }
    }
    // メインのキーウィンドウが見つからない場合は nil を返す
    return nil;
}
@end
