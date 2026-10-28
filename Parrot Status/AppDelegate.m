//
//  AppDelegate.m
//  Parrot Status
//
//  Created by Vincent Le Normand on 29/10/2014.
//  Copyright (c) 2014 Vincent Le Normand. All rights reserved.
//

#import "AppDelegate.h"
#import <IOBluetooth/IOBluetooth.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UserNotifications/UserNotifications.h>

typedef NS_ENUM(NSInteger, PSState) {
	PSAskingStateInit,
	PSAskingStateConnected,
};

@interface AppDelegate () <UNUserNotificationCenterDelegate>
@property (weak) IBOutlet NSWindow *advancedBatteryWindow;
@end

@implementation AppDelegate {
	NSStatusItem * statusItem;
	BluetoothRFCOMMChannelID channelId;
	IOBluetoothRFCOMMChannel * mRfCommChannel;
	PSState state;
	
	// State
	unsigned char batteryLevel;
	BOOL batteryCharging;
	NSString * version;
	NSString * name;
	BOOL autoConnection;
	BOOL ancPhoneMode;
	BOOL noiseCancel;
	BOOL louReedMode;
	BOOL concertHall;
	CFAbsoluteTime showUntilDate;
}

+ (void) initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
															  @"ShowBatteryNotifications":@YES,
															  @"ShowBatteryAboutToDieNotifications":@YES,
															  @"BatteryNotificationLevels":@[@"20%",@"10%"],
															  @"ShowBatteryPercentage":@NO,
															  @"ShowBatteryIcon":@YES,
															  @"HiddenWhenDisconnected":@NO,
															  @"LoginItemConfigured":@NO
															  }];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	// Open at login by default the first time, as older versions did. The user can turn it off from the menu.
	NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
	if(![userDefaults boolForKey:@"LoginItemConfigured"]) {
		NSError * error = nil;
		if(![[SMAppService mainAppService] registerAndReturnError:&error])
			NSLog(@"Failed to register login item: %@", error);
		[userDefaults setBool:YES forKey:@"LoginItemConfigured"];
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"HiddenWhenDisconnected"] && state != PSAskingStateConnected) {
		showUntilDate = CFAbsoluteTimeGetCurrent()+30.;
		[self updateStatusItem];
		[statusItem.button performClick:nil];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(31 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self updateStatusItem];
		});
	}
	return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self setupStatusItem];
	UNUserNotificationCenter * notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
	notificationCenter.delegate = self;
	[notificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError * error) {
		if(error)
			NSLog(@"Notification authorization failed: %@", error);
	}];
	[IOBluetoothDevice registerForConnectNotifications:self selector:@selector(connected:fromDevice:)];
}

- (void) setupStatusItem {
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	[self updateStatusItem];
	NSMenu * myMenu = [[NSMenu alloc] initWithTitle:@"Parrot Status"];
	myMenu.delegate = self;
	statusItem.menu = myMenu;
	statusItem.button.appearsDisabled = YES;
}

// The app has no windows in front, so show battery notifications even while it is active.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
	completionHandler(UNNotificationPresentationOptionBanner|UNNotificationPresentationOptionSound);
}

- (void) updateStatusItem {
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"HiddenWhenDisconnected"]) {
		if(state != PSAskingStateConnected && showUntilDate<CFAbsoluteTimeGetCurrent() ) {
			[statusItem.statusBar removeStatusItem:statusItem];
			statusItem = nil;
			return;
		}
		else {
			if(statusItem==nil) {
				[self setupStatusItem];
			}
		}
	}
	NSImage * image = nil;
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryIcon"]) {
		CGFloat imageWidth = (state == PSAskingStateConnected) ? 22 : 16;
		image = [NSImage imageWithSize:NSMakeSize(imageWidth, 16) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
			[[NSColor colorWithDeviceWhite:0.0 alpha:0.9] set];
			NSBezierPath  * headset = [NSBezierPath bezierPath];
			[headset moveToPoint:NSMakePoint(1.5, 4.5)];
			[headset curveToPoint:NSMakePoint(9.5, 4.5) controlPoint1:NSMakePoint(4.5, 16.5) controlPoint2:NSMakePoint(6.5, 16.5)];
			[headset appendBezierPathWithOvalInRect:NSMakeRect(1.5, 0.5, 2, 6)];
			[headset appendBezierPathWithOvalInRect:NSMakeRect(7.5, 0.5, 2, 6)];
			[headset setLineWidth:2.5];
			[headset stroke];
			if( state == PSAskingStateConnected) {
				[[NSColor blackColor] set];
				NSRect batteryRect = NSMakeRect(11.5,0.5,6,13);
				[[NSBezierPath bezierPathWithRect:batteryRect] stroke];
				[[NSBezierPath bezierPathWithRect:NSMakeRect(NSMidX(batteryRect)-2., NSMaxY(batteryRect), 4., 2.)] fill];
				batteryRect = NSInsetRect(batteryRect, 1, 1);
				
				if(batteryCharging)
				{
					NSRect lightningRect = NSInsetRect(batteryRect, 1, 1);
					NSBezierPath * lightning = [NSBezierPath bezierPath];
					[lightning moveToPoint:NSMakePoint(NSMaxX(lightningRect), NSMaxY(lightningRect))];
					[lightning lineToPoint:NSMakePoint(NSMinX(lightningRect), NSMidY(lightningRect)-1.)];
					[lightning lineToPoint:NSMakePoint(NSMaxX(lightningRect), NSMidY(lightningRect)+1.)];
					[lightning lineToPoint:NSMakePoint(NSMinX(lightningRect), NSMinY(lightningRect))];
					[lightning stroke];
				}
				
				
				batteryRect.size.height *= ((CGFloat)batteryLevel)/100.0;
				[[NSBezierPath bezierPathWithRect:batteryRect] fill];
			}
			//		NSRectFill(dstRect);
			return YES;
		}];
		[image setTemplate:YES];
	}
	else {
		image = nil;
	}
	statusItem.button.image = image;

	NSString * title = nil;
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryPercentage"]) {
		if( state == PSAskingStateConnected) {
			if(batteryCharging) {
				title = NSLocalizedString(@"Charging", @"");
			}
			else {
				title = [NSString stringWithFormat:NSLocalizedString(@"%i%%", @""),batteryLevel];
			}
		}
		else {
			title = NSLocalizedString(@"-", @"");
		}
		statusItem.length = NSVariableStatusItemLength;
	}
	else {
		title = nil;
		statusItem.length = NSSquareStatusItemLength;
	}
	
	statusItem.button.title = title ?: @"";
	statusItem.button.appearsDisabled = state != PSAskingStateConnected;
	statusItem.button.imagePosition = NSImageRight;
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
	[menu removeAllItems];
	if( state == PSAskingStateConnected) {
		[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@", @""),name] action:NULL keyEquivalent:@""];
		[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Version %@", @""),version] action:NULL keyEquivalent:@""];
		NSMenuItem * batteryMenuItem = nil;
		NSMenu * batteryMenu = [[NSMenu alloc] initWithTitle:@""];
		if(batteryCharging) {
			batteryMenuItem =[menu addItemWithTitle:NSLocalizedString(@"Battery level: Charging", @"") action:NULL keyEquivalent:@""];
		}
		else {
			batteryMenuItem =[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Battery level: %i%%", @""),batteryLevel] action:NULL keyEquivalent:@""];
		}
		batteryMenuItem.submenu = batteryMenu;
		
		BOOL showBatteryPercentage = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryPercentage"];
		BOOL showBatteryIcon = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryIcon"];
		
		[[batteryMenu addItemWithTitle:NSLocalizedString(@"Show Battery Icon Only", @"") action:@selector(showBatteryIconOnly:) keyEquivalent:@""] setState:(showBatteryIcon&&!showBatteryPercentage)?NSControlStateValueOn:NSControlStateValueOff];
		[[batteryMenu addItemWithTitle:NSLocalizedString(@"Show Battery Icon And Percentage", @"") action:@selector(showBatteryIconAndText:) keyEquivalent:@""] setState:(showBatteryIcon&&showBatteryPercentage)?NSControlStateValueOn:NSControlStateValueOff];
		[[batteryMenu addItemWithTitle:NSLocalizedString(@"Show Battery Percentage Only", @"") action:@selector(showBatteryTextOnly:) keyEquivalent:@""] setState:(!showBatteryIcon&&showBatteryPercentage)?NSControlStateValueOn:NSControlStateValueOff];
		
		[menu addItem:[NSMenuItem separatorItem]];
		[[menu addItemWithTitle:NSLocalizedString(@"Noise cancellation", @"") action:@selector(toggleNoiseCancellation:) keyEquivalent:@""] setState:noiseCancel?NSControlStateValueOn:NSControlStateValueOff];
		[[menu addItemWithTitle:NSLocalizedString(@"Noise cancellation on calls", @"") action:@selector(toggleAncPhoneMode:) keyEquivalent:@""] setState:ancPhoneMode?NSControlStateValueOn:NSControlStateValueOff];
		[[menu addItemWithTitle:NSLocalizedString(@"Auto connection", @"") action:@selector(toggleAutoConnect:) keyEquivalent:@""] setState:autoConnection?NSControlStateValueOn:NSControlStateValueOff];
		[[menu addItemWithTitle:NSLocalizedString(@"Lou Reed mode", @"") action:@selector(toggleLouReed:) keyEquivalent:@""] setState:louReedMode?NSControlStateValueOn:NSControlStateValueOff];
		[[menu addItemWithTitle:NSLocalizedString(@"Concert hall mode", @"") action:@selector(toggleConcertHall:) keyEquivalent:@""] setState:concertHall?NSControlStateValueOn:NSControlStateValueOff];
	}
	else {
		NSMenuItem * notConnected = [menu addItemWithTitle:NSLocalizedString(@"Not connected",@"") action:NULL keyEquivalent:@""];
		notConnected.submenu = [[NSMenu alloc] initWithTitle:@""];
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"HiddenWhenDisconnected"]) {
			[notConnected.submenu addItemWithTitle:NSLocalizedString(@"Show when disconnected", @"") action:@selector(showWhenDisconnected:) keyEquivalent:@""];
		}
		else {
			[notConnected.submenu addItemWithTitle:NSLocalizedString(@"Hide when disconnected", @"") action:@selector(hideWhenDisconnected:) keyEquivalent:@""];
		}
	}
	[[menu addItemWithTitle:NSLocalizedString(@"Battery notifications", @"") action:@selector(toogleBatteryNotifications:) keyEquivalent:@""] setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryNotifications"]?NSControlStateValueOn:NSControlStateValueOff];
	// Shown instead of the item above while the Option key is held down
	NSMenuItem * advancedBatteryItem = [menu addItemWithTitle:NSLocalizedString(@"Battery notifications…", @"") action:@selector(showAdvancedBatteryOptions:) keyEquivalent:@""];
	advancedBatteryItem.keyEquivalentModifierMask = NSEventModifierFlagOption;
	advancedBatteryItem.alternate = YES;

	[menu addItem:[NSMenuItem separatorItem]];
	[[menu addItemWithTitle:NSLocalizedString(@"Open at login", @"") action:@selector(toggleOpenAtLogin:) keyEquivalent:@""] setState:[SMAppService mainAppService].status == SMAppServiceStatusEnabled?NSControlStateValueOn:NSControlStateValueOff];
	[menu addItemWithTitle:NSLocalizedString(@"About", @"") action:@selector(about:) keyEquivalent:@""];

	[menu addItem:[NSMenuItem separatorItem]];
	[menu addItemWithTitle:NSLocalizedString(@"Quit", @"") action:@selector(terminate:) keyEquivalent:@""];
}

#pragma mark -
#pragma mark IOBluetoothUserNotification

static NSArray * uuidServices = nil;
static NSArray * uuidServicesZik2 = nil;
- (void)connected:(IOBluetoothUserNotification *)note fromDevice:(IOBluetoothDevice *)device
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        //0ef0f502-f0ee-46c9-986c-54ed027807fb Zik 1
        //8b6814d3-6ce7-4498-9700-9312c1711f63 Zik 2
		NSUUID * uuid = [[NSUUID alloc] initWithUUIDString:@"0ef0f502-f0ee-46c9-986c-54ed027807fb"];
		uuid_t uuidbuf;
		[uuid getUUIDBytes:uuidbuf];
		IOBluetoothSDPUUID * uuidBlutooth = [IOBluetoothSDPUUID uuidWithBytes:uuidbuf length:16];
		uuidServices = @[uuidBlutooth];

        NSUUID * uuidZik2 = [[NSUUID alloc] initWithUUIDString:@"8b6814d3-6ce7-4498-9700-9312c1711f63"];
        uuid_t uuidZik2buf;
        [uuidZik2 getUUIDBytes:uuidZik2buf];
        IOBluetoothSDPUUID * uuidZik2Blutooth = [IOBluetoothSDPUUID uuidWithBytes:uuidZik2buf length:16];
        uuidServicesZik2 = @[uuidZik2Blutooth];
});
	NSArray * services = device.services;
	for (IOBluetoothSDPServiceRecord * service in services) {
		if([service matchesUUIDArray:uuidServices]
           || [service matchesUUIDArray:uuidServicesZik2]) {
			IOReturn res = [service getRFCOMMChannelID:&channelId];
			if(res != kIOReturnSuccess)
			{
				NSLog(@"Failed to connect to %@", device.nameOrAddress);
			}
			else {
				NSLog(@"Connected to %@", device.nameOrAddress);
				IOBluetoothRFCOMMChannel * rfCommChannel;
				res = [device openRFCOMMChannelSync:&rfCommChannel withChannelID:channelId delegate:self];
				if(res != kIOReturnSuccess) {
					NSLog(@"Failed to open channel to %@ (0x%x)", device.nameOrAddress, res);
					return;
				}
				mRfCommChannel = rfCommChannel;
				unsigned char buffer[] = {0x00,0x03,0x00};
				state = PSAskingStateInit;
				res = [rfCommChannel writeSync:buffer length:3];
				if(res != kIOReturnSuccess) {
					NSLog(@"Failed to send init to %@ (0x%x)", device.nameOrAddress, res);
					return;
				}
				[device registerForDisconnectNotification:self selector:@selector(disconnected:fromDevice:)];
			}
		}
	}
}
- (void)disconnected:(IOBluetoothUserNotification *)note fromDevice:(IOBluetoothDevice *)device
{
	NSArray * services = device.services;
	for (IOBluetoothSDPServiceRecord * service in services) {
		if([service matchesUUIDArray:uuidServices]
           || [service matchesUUIDArray:uuidServicesZik2]) {
			NSLog(@"Disconnected from %@", device.nameOrAddress);
			state = PSAskingStateInit;
			[self updateStatusItem];
		}
	}
}

- (void) sendRequest:(NSString*)request {
	NSString * requestString = request;
	NSMutableData * requestData = [NSMutableData data];
	unsigned char buffer = 0;
	[requestData appendBytes:&buffer length:1];
	buffer = [requestString lengthOfBytesUsingEncoding:NSASCIIStringEncoding]+3;
	[requestData appendBytes:&buffer length:1];
	buffer = 0x80;
	[requestData appendBytes:&buffer length:1];
	[requestData appendData:[requestString dataUsingEncoding:NSASCIIStringEncoding]];
//	IOReturn res = [mRfCommChannel writeSync:(void *)[requestData bytes] length:[requestData length]];
	IOReturn res = [mRfCommChannel writeAsync:(void *)[requestData bytes] length:[requestData length] refcon:NULL];
	if(res != kIOReturnSuccess)
		NSLog(@"Failed to send %@ (0x%x)", request, res);
}

- (void) handleAnswer:(NSXMLDocument*) xmlDocument {
	NSString * path = [[[xmlDocument rootElement] attributeForName:@"path"] stringValue];
//	NSLog(@"answer for path:%@ : %@",path,xmlDocument);
	if([path isEqualToString:@"/api/software/version/get"]) {
		version = [[[[xmlDocument nodesForXPath:@"//software" error:NULL] lastObject] attributeForName:@"version"] stringValue];
        if(version == nil)
            //Zik 2
            version = [[[[xmlDocument nodesForXPath:@"//software" error:NULL] lastObject] attributeForName:@"sip6"] stringValue];
	}
	else if([path isEqualToString:@"/api/bluetooth/friendlyname/get"]) {
		name = [[[[xmlDocument nodesForXPath:@"//bluetooth" error:NULL] lastObject] attributeForName:@"friendlyname"] stringValue];
	}
	else if([path isEqualToString:@"/api/system/battery/get"]) {
		char newBatteryLevel = [[[[[xmlDocument nodesForXPath:@"//battery" error:NULL] lastObject] attributeForName:@"level"] stringValue] intValue];
        if(newBatteryLevel == '\0')
            //Zik 2
            newBatteryLevel = [[[[[xmlDocument nodesForXPath:@"//battery" error:NULL] lastObject] attributeForName:@"percent"] stringValue] intValue];
		batteryCharging = [[[[[xmlDocument nodesForXPath:@"//battery" error:NULL] lastObject] attributeForName:@"state"] stringValue] isEqualToString:@"charging"];
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryNotifications"] && batteryCharging == NO) {
			UNMutableNotificationContent * userNotification = nil;
			NSArray * notificationLevels = [[NSUserDefaults standardUserDefaults] arrayForKey:@"BatteryNotificationLevels"];
			NSMutableArray * sortedNotificationLevels = [NSMutableArray array];
			for (NSString * currentLevel in notificationLevels) {
				[sortedNotificationLevels addObject:@([currentLevel intValue])];
			}
			[sortedNotificationLevels sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
				return [obj2 compare:obj1];
			}];
			for (NSString * currentLevel in sortedNotificationLevels) {
				if(batteryLevel > [currentLevel intValue] && newBatteryLevel <= [currentLevel intValue] ) {
					userNotification = [[UNMutableNotificationContent alloc] init];
					userNotification.title = NSLocalizedString(@"Parrot Zik Battery Notification", @"");
					userNotification.subtitle = [NSString stringWithFormat:NSLocalizedString(@"%i%% of battery remaining", @""),[currentLevel intValue]];
					break;
				}
			}
			if(!userNotification && [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowBatteryAboutToDieNotifications"] && batteryLevel>=2 && newBatteryLevel<2) {
				userNotification = [[UNMutableNotificationContent alloc] init];
				userNotification.title = NSLocalizedString(@"Parrot Zik Battery Low", @"");
				userNotification.subtitle = NSLocalizedString(@"Recharge the battery soon", @"");
			}
			
			if( ( batteryLevel == 100 &&  newBatteryLevel == 0) || ( newBatteryLevel > batteryLevel)) {
				userNotification = nil; // Fix wrong notificaiton when disconnecting recharge cable
			}
			
			if( userNotification ) {
				userNotification.sound = [UNNotificationSound defaultSound];
				UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString] content:userNotification trigger:nil];
				[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * error) {
					if(error)
						NSLog(@"Failed to deliver notification: %@", error);
				}];
			}
		}
		
		batteryLevel = newBatteryLevel;
		[self updateStatusItem];
	}
	else if([path isEqualToString:@"/api/audio/noise_cancellation/enabled/get"]) {
		noiseCancel = [[[[[xmlDocument nodesForXPath:@"//noise_cancellation" error:NULL] lastObject] attributeForName:@"enabled"] stringValue] isEqualToString:@"true"];
	}
	else if([path isEqualToString:@"/api/system/auto_connection/enabled/get"]) {
		autoConnection = [[[[[xmlDocument nodesForXPath:@"//auto_connection" error:NULL] lastObject] attributeForName:@"enabled"] stringValue] isEqualToString:@"true"];
	}
	else if([path isEqualToString:@"/api/audio/specific_mode/enabled/get"]) {
		louReedMode = [[[[[xmlDocument nodesForXPath:@"//specific_mode" error:NULL] lastObject] attributeForName:@"enabled"] stringValue] isEqualToString:@"true"];
	}
	else if([path isEqualToString:@"/api/audio/sound_effect/enabled/get"]) {
		concertHall = [[[[[xmlDocument nodesForXPath:@"//sound_effect" error:NULL] lastObject] attributeForName:@"enabled"] stringValue] isEqualToString:@"true"];
	}
	else if([path isEqualToString:@"/api/system/anc_phone_mode/enabled/get"]) {
		ancPhoneMode = [[[[[xmlDocument nodesForXPath:@"//anc_phone_mode" error:NULL] lastObject] attributeForName:@"enabled"] stringValue] isEqualToString:@"true"];
	}
	else if([[NSUserDefaults standardUserDefaults] boolForKey:@"ProbeAPI"]) {
		// Already logged in full by rfcommChannelData:
	}
	else {
		NSLog(@"Unknown answer : %@ %@ ",path,xmlDocument);
	}
	[self menuNeedsUpdate:statusItem.menu];
	[statusItem.menu update];
}

- (void)rfcommChannelData:(IOBluetoothRFCOMMChannel*)rfcommChannel data:(void *)dataPointer length:(size_t)dataLength {
	NSData * data = [NSData dataWithBytes:dataPointer length:dataLength];
	UInt16 messageLen = 0;
	[data getBytes:&messageLen range:NSMakeRange(0, 2)];
	unsigned char magic = 0;
	[data getBytes:&magic range:NSMakeRange(2, 1)];
	switch (magic) {
		case 128:
		{
			NSData * xmlData = nil;
			if(data.length > 7)
				xmlData = [data subdataWithRange:NSMakeRange(7, [data length]-7)];
			NSXMLDocument * xmlDocument = [[NSXMLDocument alloc] initWithData:xmlData options:0 error:NULL];
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"ProbeAPI"])
				NSLog(@"PROBE answer: %@", xmlData ? [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding] : data);
			NSString * rootName = [[xmlDocument rootElement] name];
			if([rootName isEqualToString:@"answer"]) {
				[self handleAnswer:xmlDocument];
			}
			else if([rootName isEqualToString:@"notify"]) {
				NSString * path = [[[xmlDocument rootElement] attributeForName:@"path"] stringValue];
				[self sendRequest:[NSString stringWithFormat:@"GET %@",path]];
			}
			else {
				NSLog(@"Unknown callback %@",xmlDocument);
			}
			break;
		}
		default:
			if( state == PSAskingStateInit) {
				state = PSAskingStateConnected;
				unsigned char buffer[] = {0x00,0x03,0x02};
				if(![data isEqualToData:[NSData dataWithBytes:buffer length:3]])
					NSLog(@"Received unknown init data: %@", data);
				[self sendRequest:@"GET /api/software/version/get"];
				[self sendRequest:@"GET /api/bluetooth/friendlyname/get"];
				[self sendRequest:@"GET /api/system/battery/get"];
				[self sendRequest:@"GET /api/audio/noise_cancellation/enabled/get"];
				[self sendRequest:@"GET /api/system/auto_connection/enabled/get"];
				[self sendRequest:@"GET /api/audio/specific_mode/enabled/get"];
				[self sendRequest:@"GET /api/audio/sound_effect/enabled/get"];
				[self sendRequest:@"GET /api/system/anc_phone_mode/enabled/get"];
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"ProbeAPI"])
					[self probeAPI];
			}
			break;
	}
}

// Diagnostics: launch with `open -a "Parrot Status" --args -ProbeAPI YES` and read the answers with
// `log show --last 5m --predicate 'process == "Parrot Status"' | grep PROBE`.
// Asks the headset for API paths known from the Zik 2 and the official app, to find out which ones the connected model supports.
- (void) probeAPI {
	NSArray * paths = @[
		@"/api/audio/equalizer/enabled/get",
		@"/api/audio/equalizer/preset_id/get",
		@"/api/audio/equalizer/preset_value/get",
		@"/api/audio/preset/current/get",
		@"/api/audio/sound_effect/get",
		@"/api/audio/sound_effect/room_size/get",
		@"/api/audio/sound_effect/angle/get",
		@"/api/audio/noise_control/get",
		@"/api/audio/noise_control/enabled/get",
		@"/api/audio/track/metadata/get",
		@"/api/audio/source/get",
		@"/api/system/head_detection/enabled/get",
		@"/api/system/auto_power_off/get",
		@"/api/system/device_type/get",
		@"/api/system/color/get",
		@"/api/system/pi/get",
		@"/api/system/bt_address/get",
		@"/api/system/flight_mode/get",
		@"/api/software/download_state/get",
	];
	[paths enumerateObjectsUsingBlock:^(NSString * path, NSUInteger index, BOOL * stop) {
		// One request every half second so the answers do not arrive in the same packet
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((index + 1) * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			NSLog(@"PROBE request: GET %@", path);
			[self sendRequest:[NSString stringWithFormat:@"GET %@", path]];
		});
	}];
}

//- (void)rfcommChannelOpenComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel status:(IOReturn)error {
//	NSLog(@"%s",__FUNCTION__);
//}
//- (void)rfcommChannelClosed:(IOBluetoothRFCOMMChannel*)rfcommChannel {
//	NSLog(@"%s",__FUNCTION__);
//}
//- (void)rfcommChannelControlSignalsChanged:(IOBluetoothRFCOMMChannel*)rfcommChannel {
//	NSLog(@"%s",__FUNCTION__);
//}
//- (void)rfcommChannelFlowControlChanged:(IOBluetoothRFCOMMChannel*)rfcommChannel {
//	NSLog(@"%s",__FUNCTION__);
//}
//- (void)rfcommChannelWriteComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel refcon:(void*)refcon status:(IOReturn)error {
//	NSLog(@"%s",__FUNCTION__);
//}
//- (void)rfcommChannelQueueSpaceAvailable:(IOBluetoothRFCOMMChannel*)rfcommChannel {
//	NSLog(@"%s",__FUNCTION__);
//}

#pragma mark NSTokenField delegate

// For advanced battery settings
- (NSArray *)tokenField:(NSTokenField *)tokenField
	   shouldAddObjects:(NSArray *)tokens
				atIndex:(NSUInteger)index {
	NSMutableArray * validatedTokens = [NSMutableArray array];
	NSArray * notificationLevels = [[NSUserDefaults standardUserDefaults] arrayForKey:@"BatteryNotificationLevels"];
	for (NSString * currentToken in tokens) {
		int currentIntValue = [currentToken intValue];
		if(currentIntValue <= 2 || currentIntValue > 99) {
			NSBeep();
			continue;
		}
		NSString * newValue = [NSString stringWithFormat:@"%i%%",currentIntValue];
		if([notificationLevels containsObject:newValue]){
			NSBeep();
			continue;
		}
		if([validatedTokens containsObject:newValue]){
			NSBeep();
			continue;
		}
		[validatedTokens addObject:newValue];
	}
	return validatedTokens;
}

#pragma mark Actions
- (IBAction)toogleBatteryNotifications:(id)sender {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setBool:![userDefaults boolForKey:@"ShowBatteryNotifications"] forKey:@"ShowBatteryNotifications"];
}

- (IBAction)toggleOpenAtLogin:(id)sender {
	SMAppService * service = [SMAppService mainAppService];
	NSError * error = nil;
	BOOL success = service.status == SMAppServiceStatusEnabled ? [service unregisterAndReturnError:&error] : [service registerAndReturnError:&error];
	if(!success) {
		NSLog(@"Failed to change login item: %@", error);
		if(service.status == SMAppServiceStatusRequiresApproval)
			[SMAppService openSystemSettingsLoginItems];
	}
}

- (IBAction)toggleNoiseCancellation:(id)sender {
	[self sendRequest:[NSString stringWithFormat:@"SET /api/audio/noise_cancellation/enabled/set?arg=%@",noiseCancel?@"false":@"true"]];
	[self sendRequest:@"GET /api/audio/noise_cancellation/enabled/get"];
}

- (IBAction)toggleAncPhoneMode:(id)sender {
	[self sendRequest:[NSString stringWithFormat:@"SET /api/system/anc_phone_mode/enabled/set?arg=%@",ancPhoneMode?@"false":@"true"]];
	[self sendRequest:@"GET /api/system/anc_phone_mode/enabled/get"];
}

- (IBAction)toggleAutoConnect:(id)sender {
	[self sendRequest:[NSString stringWithFormat:@"SET /api/system/auto_connection/enabled/set?arg=%@",autoConnection?@"false":@"true"]];
	[self sendRequest:@"GET /api/system/auto_connection/enabled/get"];
}

- (IBAction)toggleLouReed:(id)sender {
	if(!louReedMode && concertHall) {
		[self toggleConcertHall:sender];
	}
	[self sendRequest:[NSString stringWithFormat:@"SET /api/audio/specific_mode/enabled/set?arg=%@",louReedMode?@"false":@"true"]];
	[self sendRequest:@"GET /api/audio/specific_mode/enabled/get"];
}

- (IBAction)toggleConcertHall:(id)sender {
	if(louReedMode && !concertHall) {
		[self toggleLouReed:sender];
	}
	[self sendRequest:[NSString stringWithFormat:@"SET /api/audio/sound_effect/enabled/set?arg=%@",concertHall?@"false":@"true"]];
	[self sendRequest:@"GET /api/audio/sound_effect/enabled/get"];
}

- (IBAction)about:(id)sender {
	[NSApp orderFrontStandardAboutPanel:sender];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showAdvancedBatteryOptions:(id)sender {
	[self.advancedBatteryWindow makeKeyAndOrderFront:sender];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showBatteryIconOnly:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowBatteryPercentage"];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowBatteryIcon"];
	[self updateStatusItem];
}

- (IBAction)showBatteryIconAndText:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowBatteryPercentage"];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowBatteryIcon"];
	[self updateStatusItem];
}

- (IBAction)showBatteryTextOnly:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ShowBatteryPercentage"];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowBatteryIcon"];
	[self updateStatusItem];
}

- (IBAction)hideWhenDisconnected:(id)sender {
	NSAlert * alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"Parrot Status will be hidden when device is disconnected", @"");
	alert.informativeText = NSLocalizedString(@"To show menu when the device is disconnected, you will have to launch the app again.", @"");
	[alert addButtonWithTitle:NSLocalizedString(@"Hide", @"")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
	NSModalResponse response = [alert runModal];
	if(response == NSAlertFirstButtonReturn) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HiddenWhenDisconnected"];
		[self updateStatusItem];
	}
}

- (IBAction)showWhenDisconnected:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"HiddenWhenDisconnected"];
	[self updateStatusItem];
}

@end
