# CastBrowser iOS & iPadOS

A native iOS & iPadOS browser designed to discover video streams from web pages and cast them seamlessly to Smart TVs (via AirPlay 2 and DLNA/UPnP) with multi-tab persistence and local watch progress tracking.

Inspired by [CastBrowser Android](../cast-browser), tailored natively for Apple platforms with SwiftUI, WebKit, SwiftData, and AVKit.

## Core Architecture

```
CastBrowser/
├── Sources/
│   ├── App/          # App lifecycle & entry point
│   ├── Browser/      # WKWebView pool, content blockers, tab state
│   ├── Detect/       # Video stream sniffer (WKUserScript + URLSession prober)
│   ├── Cast/         # AirPlay (AVRoutePicker) & DLNA (NWConnectionGroup SSDP + SOAP)
│   ├── Proxy/        # Local embedded HTTP proxy & HLS playlist rewriter
│   ├── Data/         # SwiftData entities (Tabs, History, WatchProgress, Bookmarks)
│   └── UI/           # SwiftUI views (adaptive iPadOS / iOS navigation)
└── Resources/        # Info.plist & assets
```

## System Requirements
- Xcode 15.0+
- iOS / iPadOS 17.0+
- Swift 5.9 / Swift 6

## Build & Verify

```bash
xcodebuild -project CastBrowser.xcodeproj -target CastBrowser -sdk iphoneos -configuration Debug build CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""
```
