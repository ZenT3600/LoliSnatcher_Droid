import 'dart:io';
import 'dart:math';
import 'dart:async';


import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:LoliSnatcher/ServiceHandler.dart';
import 'package:LoliSnatcher/ViewUtils.dart';
import 'package:LoliSnatcher/widgets/CachedThumbBetter.dart';
import 'package:LoliSnatcher/widgets/DioDownloader.dart';
import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/ViewerHandler.dart';
import 'package:LoliSnatcher/libBooru/BooruItem.dart';
import 'package:LoliSnatcher/widgets/LoadingElement.dart';
import 'package:LoliSnatcher/widgets/LoliControls.dart';

class VideoApp extends StatefulWidget {
  final BooruItem booruItem;
  final int index;
  final SearchGlobal searchGlobal;
  final bool enableFullscreen;
  VideoApp(Key? key, this.booruItem, this.index, this.searchGlobal, this.enableFullscreen) : super(key: key);
  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  final SettingsHandler settingsHandler = Get.find<SettingsHandler>();
  final SearchHandler searchHandler = Get.find<SearchHandler>();
  final ViewerHandler viewerHandler = Get.find<ViewerHandler>();

  PhotoViewScaleStateController scaleController = PhotoViewScaleStateController();
  PhotoViewController viewController = PhotoViewController();
  VideoPlayerController? videoController;
  ChewieController? chewieController;

  // VideoPlayerValue _latestValue;
  RxInt _total = 0.obs, _received = 0.obs, _startedAt = 0.obs;
  int _lastViewedIndex = -1;
  bool isFromCache = false, isStopped = false, isZoomed = false;
  List<String> stopReason = [];

  CancelToken? _dioCancelToken;
  DioLoader? client;
  File? _video;

  @override
  void didUpdateWidget(VideoApp oldWidget) {
    // force redraw on item data change
    if(oldWidget.booruItem != widget.booruItem) {
      killLoading([]);
      initVideo(false);
      updateState();
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _downloadVideo() async {
    isStopped = false;
    _startedAt.value = DateTime.now().millisecondsSinceEpoch;

    if(!settingsHandler.mediaCache) {
      // Media caching disabled - don't cache videos
      initPlayer();
      return;
    }
    switch (settingsHandler.videoCacheMode) {
      case 'Cache':
        // Cache to device from custom request
        break;

      case 'Stream+Cache':
        // Load and stream from default player network request, cache to device from custom request
        // TODO: change video handler to allow viewing and caching from single network request
        initPlayer();
        break;

      case 'Stream':
      default:
        // Only stream, notice the return
        initPlayer();
        return;
    }

    _dioCancelToken = CancelToken();
    client = DioLoader(
      widget.booruItem.fileURL,
      headers: ViewUtils.getFileCustomHeaders(widget.searchGlobal, checkForReferer: true),
      cancelToken: _dioCancelToken,
      onProgress: _onBytesAdded,
      onEvent: _onEvent,
      onError: _onError,
      onDoneFile: (File file, String url) {
        _video = file;
        // save video from cache, but restate only if player is not initialized yet
        if(!isVideoInit()) {
          initPlayer();
          updateState();
        }
      },
      cacheEnabled: settingsHandler.mediaCache,
      cacheFolder: 'media',
    );
    // client!.runRequest();
    if(settingsHandler.disableImageIsolates) {
      client!.runRequest();
    } else {
      client!.runRequestIsolate();
    }
    return;
  }

  void _onBytesAdded(int received, int total) {
    // bool isAllowedToRestate = settingsHandler.videoCacheMode == 'Cache' || !(videoController != null && videoController!.value.isInitialized);

    _received.value = received;
    _total.value = total;
    if (total > 0 && widget.booruItem.fileSize == null) {
      // set item file size if it wasn't received from api
      widget.booruItem.fileSize = total;
      // if(isAllowedToRestate) updateState();
    }
  }

  void _onEvent(String event) {
    switch (event) {
      case 'loaded':
        // 
        break;
      case 'isFromCache':
        isFromCache = true;
        break;
      case 'isFromNetwork':
        isFromCache = false;
        break;
      default:
    }
    updateState();
  }

  void _onError(Exception error) {
    //// Error handling
    if (error is DioError && CancelToken.isCancel(error)) {
      // print('Canceled by user: $imageURL | $error');
    } else {
      killLoading(['Loading Error: $error']);
      // print('Dio request cancelled: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    viewerHandler.addViewed(widget.key);
    initVideo(false);
  }

  void updateState() {
    if(this.mounted) {
      setState(() { });
    }
  }

  void initVideo(ignoreTagsCheck) {
    // viewController..outputStateStream.listen(onViewStateChanged);
    scaleController..outputScaleStateStream.listen(onScaleStateChanged);

    if (widget.booruItem.isHated.value && !ignoreTagsCheck) {
      List<List<String>> hatedAndLovedTags = settingsHandler.parseTagsList(widget.booruItem.tagsList, isCapped: true);
      killLoading(['Contains Hated tags:', ...hatedAndLovedTags[0]]);
    } else {
      _downloadVideo();
    }
  }

  void killLoading(List<String> reason) {
    disposables();

    _total.value = 0;
    _received.value = 0;
    _startedAt.value = 0;

    isFromCache = false;
    isStopped = true;
    stopReason = reason;

    resetZoom();

    _video = null;

    updateState();
  }

  @override
  void dispose() {
    disposables();
    viewerHandler.removeViewed(widget.key);
    super.dispose();
  }

  void disposeClient() {
    client?.dispose();
    client = null;
  }

  void disposables() {
    videoController?.setVolume(0);
    videoController?.pause();
    videoController?.dispose();
    chewieController?.dispose();

    if (!(_dioCancelToken != null && _dioCancelToken!.isCancelled)){
      _dioCancelToken?.cancel();
    }
    disposeClient();
  }


  // debug functions
  void onScaleStateChanged(PhotoViewScaleState scaleState) {
    // print(scaleState);

    isZoomed = scaleState == PhotoViewScaleState.zoomedIn || scaleState == PhotoViewScaleState.covering || scaleState == PhotoViewScaleState.originalSize;
    viewerHandler.setZoomed(widget.key, isZoomed);
  }

  void onViewStateChanged(PhotoViewControllerValue viewState) {
    // print(viewState);
  }

  void resetZoom() {
    if(!isVideoInit()) return;
    scaleController.scaleState = PhotoViewScaleState.initial;
  }

  void scrollZoomImage(double value) {
    final double upperLimit = min(8, (viewController.scale ?? 1) + (value / 200));
    // zoom on which image fits to container can be less than limit
    // therefore don't clump the value to lower limit if we are zooming in to avoid unnecessary zoom jumps
    final double lowerLimit = value > 0 ? upperLimit : max(0.75, upperLimit);

    // print('ll $lowerLimit $value');
    // if zooming out and zoom is smaller than limit - reset to container size
    // TODO minimal scale to fit can be different from limit
    if(lowerLimit == 0.75 && value < 0) {
      scaleController.scaleState = PhotoViewScaleState.initial;
    } else {
      viewController.scale = lowerLimit;
    }
  }

  void doubleTapZoom() {
    if(!isVideoInit()) return;
    // viewController.scale = 2;
    viewController.updateMultiple(scale: 2);
    // scaleController.scaleState = PhotoViewScaleState.originalSize;
  }

  void _updateVideoState() {
    // print(videoController?.value);
    // setState(() {
    //   _latestValue = videoController?.value;
    // });

    if(chewieController == null) return;

    if(viewerHandler.isFullscreen.value != chewieController!.isFullScreen) {
      // redisable sleep when changing fullscreen state
      ServiceHandler.disableSleep();
    }
    viewerHandler.isFullscreen.value = chewieController!.isFullScreen;

    if(widget.searchGlobal.viewedIndex.value == widget.index) {
      if(chewieController!.isFullScreen || !settingsHandler.useVolumeButtonsForScroll) {
        ServiceHandler.setVolumeButtons(true); // in full screen or volumebuttons scroll setting is disabled
      } else {
        ServiceHandler.setVolumeButtons(viewerHandler.displayAppbar.value); // same as app bar value
      }
    }
  }

  bool isVideoInit() {
    return chewieController != null && chewieController!.videoPlayerController.value.isInitialized;
  }


  Future<void> initPlayer() async {
    // Start from cache if was already cached or only caching is allowed
    if(_video != null) { // if (settingsHandler.mediaCache || _video != null) {
      videoController = VideoPlayerController.file(
        _video!,
        videoPlayerOptions: Platform.isAndroid ? VideoPlayerOptions(mixWithOthers: true) : null,
      );
    } else {
      // Otherwise load from network
      videoController = VideoPlayerController.network(
        widget.booruItem.fileURL,
        videoPlayerOptions: Platform.isAndroid ? VideoPlayerOptions(mixWithOthers: true) : null,
        httpHeaders: ViewUtils.getFileCustomHeaders(widget.searchGlobal, checkForReferer: true),
      );
    }
    // mixWithOthers: true, allows to not interrupt audio sources from other apps
    await Future.wait([videoController!.initialize()]);
    videoController?.addListener(_updateVideoState);

    // Player wrapper to allow controls, looping...
    chewieController = ChewieController(
      videoPlayerController: videoController!,
      // autoplay is disabled here, because videos started playing randomly, but videos will still autoplay when in view (see isViewed check later)
      autoPlay: false,
      allowedScreenSleep: false,
      looping: true,
      allowFullScreen: widget.enableFullscreen,
      showControls: true,
      showControlsOnInitialize: viewerHandler.displayAppbar.value,
      customControls: SafeArea(child: LoliControls()),
      // TODO safe area replaces hideable padding?
        // settingsHandler.galleryBarPosition == 'Bottom'
        //   ? SafeArea(child: HideableControlsPadding(LoliControls()))
        //   : SafeArea(child: LoliControls()),

        // MaterialControls(),
        // CupertinoControls(
        //   backgroundColor: Color.fromRGBO(41, 41, 41, 0.7),
        //   iconColor: Color.fromARGB(255, 200, 200, 200)
        // ),
      materialProgressColors: ChewieProgressColors(
        playedColor: Get.theme.colorScheme.secondary,
        handleColor: Get.theme.colorScheme.secondary,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white,
      ),
      // placeholder: Container(
      //   color: Colors.black,
      // ),
      systemOverlaysOnEnterFullScreen: [],
      systemOverlaysAfterFullScreen: [],
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(errorMessage, style: TextStyle(color: Colors.white)),
        );
      },

      // Specify this to allow any orientation in fullscreen, otherwise it will decide for itself based on video dimensions
      // deviceOrientationsOnEnterFullScreen: [
      //     DeviceOrientation.landscapeLeft,
      //     DeviceOrientation.landscapeRight,
      //     DeviceOrientation.portraitUp,
      //     DeviceOrientation.portraitDown,
      // ],
    );

    // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
    updateState();
  }

  @override
  Widget build(BuildContext context) {
    int viewedIndex = widget.searchGlobal.viewedIndex.value;
    final bool isViewed = settingsHandler.appMode == 'Mobile'
      ? viewedIndex == widget.index
      : widget.searchGlobal.currentItem.value.fileURL == widget.booruItem.fileURL;
    bool initialized = isVideoInit();

    // protects from video restart when something forces restate here while video is active (example: favoriting from appbar)
    bool needsRestart = _lastViewedIndex != viewedIndex;

    if (!isViewed) {
      // reset zoom if not viewed
      resetZoom();
    } else {
      viewerHandler.setCurrent(widget.key);
    }

    if (initialized) {
      if (isViewed) {
        // Reset video time if came into view
        if(needsRestart) {
          videoController!.seekTo(Duration.zero);
        }
        if (settingsHandler.autoPlayEnabled) {
          // autoplay if viewed and setting is enabled
          videoController!.play();
        }
        if (viewerHandler.videoAutoMute){
          videoController!.setVolume(0);
        }
      } else {
        videoController!.pause();
      }
    }

    if(needsRestart) {
      _lastViewedIndex = viewedIndex;
    }

    // print('!!! Build video mobile !!!');

    // TODO move controls outside of chewie, to exclude them from zoom

    return Hero(
      tag: 'imageHero' + (isViewed ? '' : 'ignore') + widget.index.toString(),
      child: Material(
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if(pointerSignal is PointerScrollEvent) {
              scrollZoomImage(pointerSignal.scrollDelta.dy);
            }
          },
          child: PhotoView.customChild(
            child: initialized
              ? Chewie(controller: chewieController!)
              : Stack(children: [
                  CachedThumbBetter(widget.booruItem, widget.index, widget.searchGlobal, 1, false),
                  LoadingElement(
                    item: widget.booruItem,
                    hasProgress: settingsHandler.mediaCache && settingsHandler.videoCacheMode != 'Stream',
                    isFromCache: isFromCache,
                    isDone: initialized,
                    isStopped: isStopped,
                    stopReasons: stopReason,
                    isViewed: isViewed,
                    total: _total,
                    received: _received,
                    startedAt: _startedAt,
                    startAction: () {
                      initVideo(true);
                      updateState();
                    },
                    stopAction: () {
                      killLoading(['Stopped by User']);
                    },
                  ),
                ]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 8,
            initialScale: PhotoViewComputedScale.contained,
            enableRotation: false,
            basePosition: Alignment.center,
            controller: viewController,
            // tightMode: true,
            scaleStateController: scaleController,
          )
        )
      )
    );
  }
}
